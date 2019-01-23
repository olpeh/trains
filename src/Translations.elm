module Translations exposing (HtmlTranslationKey(..), Language(..), T, TranslationKey(..), allLanguages, htmlTranslate, languageToString, stringToLanguage, translate)

import FinnishConjugation
import Html exposing (..)
import Html.Attributes exposing (..)


type Language
    = Finnish
    | English
    | Swedish


allLanguages : List Language
allLanguages =
    [ Finnish
    , English
    , Swedish
    ]


languageToString : Language -> String
languageToString language =
    case language of
        English ->
            "EN"

        Finnish ->
            "FI"

        Swedish ->
            "SV"


stringToLanguage : String -> Maybe Language
stringToLanguage string =
    case string of
        "EN" ->
            Just English

        "FI" ->
            Just Finnish

        "SV" ->
            Just Swedish

        _ ->
            Nothing


type alias T =
    TranslationKey -> String


type TranslationKey
    = DepPageTitle
    | DepPageHeading
    | DestPageTitle
    | DestPageHeading
    | ErrorNetwork
    | ErrorTimeout
    | ErrorBadUrl
    | ErrorBadStatus
    | ErrorBadPayload
    | SchedulePageLoading
    | SchedulePageJourneyDuration { durationMinutes : Int, slowerBy : Int, fastestName : String }
    | SchedulePageArrivesIn
    | SchedulePageDepartsIn
    | SchedulePageTimeDifference { minuteDiff : Int, stationName : String }
    | SchedulePageNotMoving
    | SchedulePageCancelled
    | SchedulePageEndOfListNote
    | SettingsPageTitle
    | SettingsPageHeading
    | SettingsPageSelectLanguage


type alias TranslationSet =
    { english : String
    , finnish : String
    , swedish : String
    }


translate : Language -> T
translate language translationKey =
    let
        translationSet =
            translationSetFor translationKey
    in
    case language of
        Finnish ->
            translationSet.finnish

        English ->
            translationSet.english

        Swedish ->
            translationSet.swedish


translationSetFor : TranslationKey -> TranslationSet
translationSetFor translationKey =
    case translationKey of
        DepPageTitle ->
            { english = "Trains.today - Helsinki region commuter trains"
            , finnish = "Trains.today - Helsingin seudun lähijunat"
            , swedish = "Trains.today - Helsingfors regions närtåg"
            }

        DepPageHeading ->
            { english = "Select departure station"
            , finnish = "Valitse lähtöasema"
            , swedish = "Välj startstation"
            }

        DestPageTitle ->
            { english = "Select destination – Trains.today"
            , finnish = "Valitse pääteasema – Trains.today"
            , swedish = "Välj slutstation - Trains.today"
            }

        DestPageHeading ->
            { english = "Select destination station"
            , finnish = "Valitse pääteasema"
            , swedish = "Välj slutstation"
            }

        ErrorNetwork ->
            { english = "No connection, trying again soon..."
            , finnish = "Ei yhteyttä, yritetään pian uudestaan..."
            , swedish = "Ingen anslutning, försöker pånytt snart..."
            }

        ErrorTimeout ->
            { english = "Network timed out"
            , finnish = "Vastaus aikakatkaistiin"
            , swedish = "Svaret tidsavbröts"
            }

        ErrorBadUrl ->
            { english = "It's not you, it's me. I have the server address wrong."
            , finnish = "Vika on minussa. Palvelimen osoite on väärä."
            , swedish = "Det är mitt fel. Serverns adress är felaktig."
            }

        ErrorBadStatus ->
            { english = "The server didn't like the request (bad status)."
            , finnish = "Palvelin ei tykännyt pyynnöstä (virheellinen status)."
            , swedish = "Servern tyckte inte om förfrågan (bad request)."
            }

        ErrorBadPayload ->
            { english = "Ouch, the server responded with strange contents."
            , finnish = "Auts, palvelin vastasi oudolla sisällöllä."
            , swedish = "Aj, servern svarade med något konstigt."
            }

        SchedulePageLoading ->
            { english = "Loading"
            , finnish = "Ladataan"
            , swedish = "Laddar"
            }

        SchedulePageJourneyDuration params ->
            journeyDurationTranslationSet params

        SchedulePageArrivesIn ->
            { english = "Arrives in"
            , finnish = "Saapumiseen"
            , swedish = "Ankommer om"
            }

        SchedulePageDepartsIn ->
            { english = "Departs in"
            , finnish = "Lähtöön"
            , swedish = "Avgår om"
            }

        SchedulePageTimeDifference facts ->
            timeDifferenceTranslationSet facts

        SchedulePageNotMoving ->
            { english = "Not moving"
            , finnish = "Ei vielä liikkeellä"
            , swedish = "Stillastående"
            }

        SchedulePageCancelled ->
            { english = "Cancelled"
            , finnish = "Peruttu"
            , swedish = "Inhiberat"
            }

        SchedulePageEndOfListNote ->
            { english = "Only direct trains departing in 2 hours are displayed."
            , finnish = "Vain suorat 2 tunnin kuluessa lähtevät junat näytetään."
            , swedish = "Bara direkta tåg som avgår inom 2 timmar visas."
            }

        SettingsPageTitle ->
            { english = "Settings"
            , finnish = "Asetukset"
            , swedish = "Inställningar"
            }

        SettingsPageHeading ->
            { english = "Settings"
            , finnish = "Asetukset"
            , swedish = "Inställningar"
            }

        SettingsPageSelectLanguage ->
            { english = "Select language"
            , finnish = "Valitse kieli"
            , swedish = "Välj språk"
            }


type HtmlTranslationKey
    = PageFooter


type alias HtmlTranslationSet msg =
    { english : Html msg
    , finnish : Html msg
    , swedish : Html msg
    }


htmlTranslate : Language -> HtmlTranslationKey -> Html msg
htmlTranslate language key =
    let
        translationSet =
            htmlTranslationSetFor key
    in
    case language of
        Finnish ->
            translationSet.finnish

        English ->
            translationSet.english

        Swedish ->
            translationSet.swedish


htmlTranslationSetFor : HtmlTranslationKey -> HtmlTranslationSet msg
htmlTranslationSetFor key =
    case key of
        PageFooter ->
            { english =
                Html.footer []
                    [ p []
                        [ text "Made with "
                        , span [ class "pink" ] [ text "♥" ]
                        , text " by "
                        , a [ href "https://twitter.com/ohanhi" ] [ text "@ohanhi" ]
                        , text " – "
                        , text "Open Source on "
                        , a [ href "https://github.com/ohanhi/trains" ] [ text "GitHub" ]
                        ]
                    , p [ class "small" ]
                        [ text "Data provided by "
                        , a [ href "https://rata.digitraffic.fi/" ] [ text "Digitraffic" ]
                        ]
                    ]
            , finnish =
                Html.footer []
                    [ p []
                        [ text "Palvelun tehnyt "
                        , span [ class "pink" ] [ text "♥" ]
                        , text " "
                        , a [ href "https://twitter.com/ohanhi" ] [ text "@ohanhi" ]
                        , text " – "
                        , text "Avoin lähdekoodi "
                        , a [ href "https://github.com/ohanhi/trains" ] [ text "GitHubissa" ]
                        ]
                    , p [ class "small" ]
                        [ text "Tiedot tarjoaa "
                        , a [ href "https://rata.digitraffic.fi/" ] [ text "Digitraffic" ]
                        ]
                    ]
            , swedish =
                Html.footer []
                    [ p []
                        [ text "Servicen gjord med "
                        , span [ class "pink" ] [ text "♥" ]
                        , text " av "
                        , a [ href "https://twitter.com/ohanhi" ] [ text "@ohanhi" ]
                        , text " – "
                        , text "Öppen källkod på "
                        , a [ href "https://github.com/ohanhi/trains" ] [ text "GitHub" ]
                        ]
                    , p [ class "small" ]
                        [ text "Data från "
                        , a [ href "https://rata.digitraffic.fi/" ] [ text "Digitraffic" ]
                        ]
                    ]
            }


journeyDurationTranslationSet : { durationMinutes : Int, slowerBy : Int, fastestName : String } -> TranslationSet
journeyDurationTranslationSet { durationMinutes, slowerBy, fastestName } =
    let
        dMin =
            String.fromInt durationMinutes ++ " min"

        slowerPrefix =
            dMin ++ " · " ++ String.fromInt slowerBy ++ " min "
    in
    if slowerBy < 4 then
        { english = dMin ++ " · fast"
        , finnish = dMin ++ " · nopea"
        , swedish = dMin ++ " · snabbt"
        }

    else
        { english = slowerPrefix ++ "slower than " ++ fastestName
        , finnish = slowerPrefix ++ "hitaampi kuin " ++ fastestName
        , swedish = slowerPrefix ++ "långsammare än " ++ fastestName
        }


timeDifferenceTranslationSet : { minuteDiff : Int, stationName : String } -> TranslationSet
timeDifferenceTranslationSet { minuteDiff, stationName } =
    let
        absDiff =
            abs minuteDiff

        absDiffString =
            String.fromInt absDiff
    in
    if absDiff <= 1 then
        { english = "On time in " ++ stationName
        , finnish = "Ajallaan " ++ finnishInessive stationName
        , swedish = "Enligt tidtabell i " ++ stationName
        }

    else if minuteDiff < 0 then
        { english = absDiffString ++ " min early in " ++ stationName
        , finnish = absDiffString ++ " min ajoissa " ++ finnishInessive stationName
        , swedish = absDiffString ++ " min i förtid i " ++ stationName
        }

    else
        { english = absDiffString ++ " min late in " ++ stationName
        , finnish = absDiffString ++ " min myöhässä " ++ finnishInessive stationName
        , swedish = absDiffString ++ " min sen i " ++ stationName
        }


finnishInessive : String -> String
finnishInessive stationName =
    case FinnishConjugation.conjugate stationName of
        Just { in_ } ->
            in_

        Nothing ->
            "- " ++ stationName
