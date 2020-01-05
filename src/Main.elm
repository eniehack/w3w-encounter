port module Main exposing (main)

import Browser
import Html exposing (Html, div, text)
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
    }


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
    ( Model flag.apiKey { latitude = 0, longitude = 0 } Nothing flag.supportGeolocation
    , Cmd.none
    )


type Msg
    = Refresh D.Value



-- UPDATE


port receiveLocation : (D.Value -> msg) -> Sub msg


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
                            , Cmd.none
                            )

                Err _ ->
                    ( { model | error = Just "port error" }
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
                , div []
                    (if model.geolocationAPIEnable then
                        [ text "Geolocation API: enabled" ]

                     else
                        [ text "Geolocation API: disabled" ]
                    )
                ]
