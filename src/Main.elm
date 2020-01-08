port module Main exposing (main)

import Browser
import Html exposing (Html, div, text)
import Http
import Json.Decode as D


main : Program Flag Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias APIKey =
    String


type alias Flag =
    { apiKey : APIKey
    , supportGeolocation : Bool
    }


type alias Location =
    { latitude : Float
    , longitude : Float
    }

type alias ReceiveLocation =
    { location : Maybe Location
    , errorCode : Maybe Int
    }

type alias Model =
    { apiKey : APIKey
    , location : Location
    , error : Maybe String
    , geolocationAPIEnable : Bool
    , threeWordAddress : Maybe String
    }

convertTo3WADecoder : D.Decoder String
convertTo3WADecoder =
    D.field "words" D.string

locationDecoder : D.Decoder Location
locationDecoder =
    D.map2 Location
        (D.field "latitude" D.float)
        (D.field "longitude" D.float)


receiveLocationDecoder : D.Decoder ReceiveLocation
receiveLocationDecoder =
    D.map2 ReceiveLocation
        (D.field "location" (D.maybe locationDecoder))
        (D.field "errorCode" (D.maybe D.int))


init : Flag -> ( Model, Cmd Msg )
init flag =
    ( Model flag.apiKey { latitude = 0, longitude = 0 } Nothing flag.supportGeolocation Nothing
    , Cmd.none
    )


type Msg
    = Refresh D.Value
    | Get3WA (Result Http.Error String)



-- UPDATE


port receiveLocation : (D.Value -> msg) -> Sub msg


makeGet3WAUrl : APIKey -> Location -> String
makeGet3WAUrl apiKey location =
    String.concat
        [ "https://api.what3words.com/v3/convert-to-3wa?key="
        , apiKey
        , "&coordinates="
        , String.fromFloat location.latitude
        , ","
        , String.fromFloat location.longitude
        , "&language=ja&format=json"
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Refresh message ->
            let
                errormsg =
                    D.decodeValue receiveLocationDecoder message
            in
            case errormsg of
                Ok status ->
                    case status.errorCode of
                        Just errorCode ->
                            ( { model | error = Just ("GeolocationAPI Error code:" ++ String.fromInt errorCode) }
                            , Cmd.none
                            )

                        Nothing ->
                            let
                                newLocation =
                                    Maybe.withDefault { latitude = 0, longitude = 0 } status.location
                            in
                            ( { model | location = newLocation }
                            , Http.request
                                { method = "GET"
                                , headers =
                                    [ Http.header "Accept" "application/json"
                                    ]
                                , url = makeGet3WAUrl model.apiKey model.location
                                , expect = Http.expectJson Get3WA convertTo3WADecoder
                                , timeout = Nothing
                                , tracker = Nothing
                                , body = Http.emptyBody
                                }
                            )

                Err _ ->
                    ( { model | error = Just "port error" }
                    , Cmd.none
                    )

        Get3WA (Ok resultJson) ->
            ( { model | threeWordAddress = Just resultJson }
            , Cmd.none
            )

        Get3WA (Err error) ->
            case error of
                Http.BadUrl url ->
                    ( { model | error = Just (String.append "Bad URL:" url) }
                    , Cmd.none
                    )

                Http.Timeout ->
                    ( { model | error = Just "Timeout" }
                    , Cmd.none
                    )

                Http.NetworkError ->
                    ( { model | error = Just "NetworkError" }
                    , Cmd.none
                    )

                Http.BadStatus statusCode ->
                    ( { model | error = Just (String.append "Bad status" (String.fromInt statusCode)) }
                    , Cmd.none
                    )
            
                Http.BadBody status ->
                    ( { model | error = Just ( String.append "Bad body: " status) }
                    , Cmd.none
                    )




-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    receiveLocation Refresh



-- VIEW


view : Model -> Html Msg
view model =
    case model.error of
        Just errormsg ->
            div []
                [ div [] [ text errormsg ]
                , div []
                    (if model.geolocationAPIEnable then
                        [ text "Geolocation API: enabled" ]

                     else
                        [ text "Geolocation API: disabled" ]
                    )
                ]

        Nothing ->
            div []
                [ div [] [ text ("latitude: " ++ String.fromFloat model.location.latitude) ]
                , div [] [ text ("longitude: " ++ String.fromFloat model.location.longitude) ]
                , div [] [ text ("3 Word Address: " ++ Maybe.withDefault "" model.threeWordAddress )]
                , div []
                    (if model.geolocationAPIEnable then
                        [ text "Geolocation API: enabled" ]

                     else
                        [ text "Geolocation API: disabled" ]
                    )
                ]
