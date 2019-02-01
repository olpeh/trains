module Model exposing (CurrentStation, Model, Route(..), RowType(..), Stations, StoredState, Targets, TimetableRow, Train, TrainWagonCounts, Trains, decodeStoredState, defaultStoredState, encodeStoredState, mostAccurateTime, sortedTrainList, stationsDecoder, toTrain, trainWagonCountDecoder, trainsDecoder)

import Browser.Navigation
import DateFormat
import Dict exposing (Dict)
import Iso8601
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Json.Encode as Enc
import RemoteData exposing (WebData)
import Time exposing (Posix)
import Translations exposing (Language(..))
import Tuple exposing (pair)


storedStateVersion : Int
storedStateVersion =
    2


type alias StoredState =
    { language : Language
    , showTrainsViaAirport : Bool
    }


defaultStoredState : StoredState
defaultStoredState =
    { language = Finnish
    , showTrainsViaAirport = False
    }


storedStateDecoder : Decoder StoredState
storedStateDecoder =
    field "version" int
        |> andThen
            (\version ->
                case version of
                    2 ->
                        storedStateDecoderV2

                    _ ->
                        storedStateDecoderV1
            )


storedStateDecoderV2 : Decoder StoredState
storedStateDecoderV2 =
    succeed StoredState
        |> required "language" languageDecoder
        |> required "showTrainsViaAirport" bool


storedStateDecoderV1 : Decoder StoredState
storedStateDecoderV1 =
    succeed (\lang -> { defaultStoredState | language = lang })
        |> required "language" languageDecoder


languageDecoder : Decoder Language
languageDecoder =
    string
        |> andThen
            (\s ->
                case Translations.stringToLanguage s of
                    Just lang ->
                        succeed lang

                    Nothing ->
                        fail "invalid language"
            )


decodeStoredState : String -> Result Error StoredState
decodeStoredState =
    decodeString storedStateDecoder


encodeStoredState : Model -> String
encodeStoredState model =
    [ pair "version" (Enc.int storedStateVersion)
    , pair "language" (Enc.string (Translations.languageToString model.language))
    , pair "showTrainsViaAirport" (Enc.bool model.showTrainsViaAirport)
    ]
        |> Enc.object
        |> Enc.encode 0


type Route
    = SelectDepRoute
    | SelectDestRoute String
    | ScheduleRoute String String


type alias Model =
    { trains : WebData Trains
    , stations : Stations
    , wagonCounts : TrainWagonCounts
    , currentTime : Posix
    , lastRequestTime : Posix
    , route : Route
    , zone : Time.Zone
    , navKey : Browser.Navigation.Key
    , language : Translations.Language
    , showTrainsViaAirport : Bool
    }


type alias Train =
    { trainNumber : Int
    , lineId : String
    , runningCurrently : Bool
    , cancelled : Bool
    , currentStation : Maybe CurrentStation
    , homeStationArrival : Maybe TimetableRow
    , homeStationDeparture : TimetableRow
    , endStationArrival : TimetableRow
    , durationMinutes : Int
    , stopsBetween : Int
    , viaAirport : Bool
    }


type alias TrainRaw =
    { trainNumber : Int
    , lineId : String
    , trainCategory : String
    , timetableRows : List TimetableRow
    , runningCurrently : Bool
    , cancelled : Bool
    }


type alias TrainWagonCounts =
    Dict Int Int


type alias Stations =
    Dict String String


type alias Trains =
    Dict Int Train


type alias TimetableRow =
    { scheduledTime : Posix
    , trainStopping : Bool
    , stationShortCode : String
    , stationUICCode : Int
    , track : Maybe String
    , rowType : RowType
    , actualTime : Maybe Posix
    , liveEstimateTime : Maybe Posix
    , differenceInMinutes : Maybe Int
    }


type alias CurrentStation =
    { stationShortCode : String
    , stationUICCode : Int
    , rowType : RowType
    , actualTime : Posix
    , differenceInMinutes : Int
    }


type RowType
    = Departure
    | Arrival


type alias Targets =
    { from : String
    , to : String
    }


mostAccurateTime : TimetableRow -> Posix
mostAccurateTime timetableRow =
    Just timetableRow.actualTime
        |> Maybe.withDefault timetableRow.liveEstimateTime
        |> Maybe.withDefault timetableRow.scheduledTime


stationsDecoder : Decoder Stations
stationsDecoder =
    Json.Decode.succeed (\a b -> ( a, b ))
        |> required "stationShortCode" string
        |> required "stationName"
            (string |> map (String.replace " asema" ""))
        |> list
        |> andThen (Dict.fromList >> succeed)


trainsDecoder : Targets -> Decoder Trains
trainsDecoder targets =
    Json.Decode.succeed TrainRaw
        |> required "trainNumber" int
        |> required "commuterLineID" string
        |> required "trainCategory" string
        |> required "timeTableRows" timetableRowsDecoder
        |> required "runningCurrently" bool
        |> required "cancelled" bool
        |> andThen (succeed << toTrain targets)
        |> list
        |> andThen
            (List.filterMap identity
                >> List.map (\a -> ( a.trainNumber, a ))
                >> Dict.fromList
                >> succeed
            )


trainWagonCountDecoder : Decoder TrainWagonCounts
trainWagonCountDecoder =
    let
        wagonCountFromJourneySections : Decoder (Maybe Int)
        wagonCountFromJourneySections =
            succeed identity
                |> required "wagons" wagonCountFromWagons
                |> list
                |> map List.minimum

        wagonCountFromWagons : Decoder Int
        wagonCountFromWagons =
            list (succeed True)
                |> andThen (\a -> succeed (List.length a))

        liftMaybe : Int -> Maybe Int -> Maybe ( Int, Int )
        liftMaybe trainNum maybeCount =
            maybeCount |> Maybe.andThen (\count -> Just ( trainNum, count ))
    in
    succeed liftMaybe
        |> required "trainNumber" int
        |> required "journeySections" wagonCountFromJourneySections
        |> list
        |> map (List.filterMap (\a -> a) >> Dict.fromList)


sortedTrainList : Trains -> List Train
sortedTrainList trains =
    trains
        |> Dict.values
        |> List.sortBy
            (\train -> Time.posixToMillis train.homeStationDeparture.scheduledTime)


toTrain : Targets -> TrainRaw -> Maybe Train
toTrain { from, to } trainRaw =
    let
        stoppingRows =
            List.filter .trainStopping trainRaw.timetableRows

        upcomingRows =
            List.filter (\row -> row.actualTime == Nothing) stoppingRows

        homeStationDeparture =
            findTimetableRow Departure from upcomingRows

        endStationArrival =
            findTimetableRow Arrival to (List.reverse trainRaw.timetableRows)

        isValid =
            (trainRaw.trainCategory == "Commuter")
                && isRightDirection stoppingRows to homeStationDeparture

        viaAirport =
            List.member "LEN" (List.map .stationShortCode stoppingRows)
                && (List.member to [ "PSL", "HKI" ] || List.member from [ "PSL", "HKI" ])
                && isRightDirection stoppingRows "LEN" homeStationDeparture

        rowsAfterHomeStation =
            stoppingRows
                |> List.map .stationShortCode
                |> dropUntil ((==) from)
                |> List.filter ((/=) from)

        stopsBetween =
            rowsAfterHomeStation
                |> takeUntil ((==) to)
                |> List.length
    in
    case ( isValid, homeStationDeparture, endStationArrival ) of
        ( True, Just dep, Just end ) ->
            Just
                { trainNumber = trainRaw.trainNumber
                , lineId = trainRaw.lineId
                , runningCurrently = trainRaw.runningCurrently
                , cancelled = trainRaw.cancelled
                , currentStation = findCurrentStation trainRaw.timetableRows
                , homeStationArrival = findTimetableRow Arrival from upcomingRows
                , homeStationDeparture = dep
                , endStationArrival = end
                , durationMinutes = toDuration dep end
                , stopsBetween = stopsBetween
                , viaAirport = viaAirport
                }

        _ ->
            Nothing


toDuration : TimetableRow -> TimetableRow -> Int
toDuration homeStationDeparture endStationArrival =
    let
        homeTime =
            mostAccurateTime homeStationDeparture

        endTime =
            mostAccurateTime endStationArrival
    in
    (Time.posixToMillis endTime - Time.posixToMillis homeTime)
        // 60000


findTimetableRow : RowType -> String -> List TimetableRow -> Maybe TimetableRow
findTimetableRow rowType shortCode rows =
    rows
        |> List.filter
            (\row -> row.stationShortCode == shortCode && row.rowType == rowType)
        |> List.head


isRightDirection : List TimetableRow -> String -> Maybe TimetableRow -> Bool
isRightDirection rows toShortCode departureRow =
    case departureRow of
        Nothing ->
            False

        Just departure ->
            rows
                |> List.filter
                    (\row -> row.stationShortCode == toShortCode && row.rowType == Arrival)
                |> List.any
                    (\arr -> Time.posixToMillis arr.scheduledTime > Time.posixToMillis departure.scheduledTime)


findCurrentStation : List TimetableRow -> Maybe CurrentStation
findCurrentStation rows =
    rows
        |> List.filter (.actualTime >> (/=) Nothing)
        |> List.reverse
        |> List.head
        |> Maybe.andThen
            (\row ->
                Maybe.map2
                    (\actualTime differenceInMinutes ->
                        { stationShortCode = row.stationShortCode
                        , stationUICCode = row.stationUICCode
                        , rowType = row.rowType
                        , actualTime = actualTime
                        , differenceInMinutes = differenceInMinutes
                        }
                    )
                    row.actualTime
                    row.differenceInMinutes
            )


timetableRowsDecoder : Decoder (List TimetableRow)
timetableRowsDecoder =
    Json.Decode.succeed TimetableRow
        |> required "scheduledTime" dateDecoder
        |> required "trainStopping" bool
        |> required "stationShortCode" string
        |> required "stationUICCode" int
        |> optional "commercialTrack" (maybe string) Nothing
        |> required "type" rowTypeDecoder
        |> optional "actualTime" (maybe dateDecoder) Nothing
        |> optional "liveEstimateTime" (maybe dateDecoder) Nothing
        |> optional "differenceInMinutes" (maybe int) Nothing
        |> list


dateDecoder : Decoder Posix
dateDecoder =
    Iso8601.decoder


rowTypeDecoder : Decoder RowType
rowTypeDecoder =
    string
        |> andThen
            (\a ->
                case a of
                    "ARRIVAL" ->
                        succeed Arrival

                    "DEPARTURE" ->
                        succeed Departure

                    other ->
                        fail ("\"" ++ other ++ "\" is not a valid row type")
            )


dropUntil : (a -> Bool) -> List a -> List a
dropUntil predicate list =
    case list of
        [] ->
            []

        a :: rest ->
            case predicate a of
                True ->
                    rest

                False ->
                    dropUntil predicate rest


takeUntil : (a -> Bool) -> List a -> List a
takeUntil =
    takeUntilHelp []


takeUntilHelp : List a -> (a -> Bool) -> List a -> List a
takeUntilHelp acc predicate list =
    case list of
        [] ->
            []

        a :: rest ->
            case predicate a of
                True ->
                    acc

                False ->
                    takeUntilHelp (a :: acc) predicate rest
