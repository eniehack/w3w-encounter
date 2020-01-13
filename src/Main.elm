port module Main exposing (main)

import Browser
import Html exposing (Html, div, text)
import Http
import Json.Decode as D
import Bulma.CDN as CDN
import Bulma.Columns as Columns

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
    { lat : Float
    , lng : Float
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
    , threeWordAddress : Maybe ConvertTo3WordAddress
    }


locationDecoder : D.Decoder Location
locationDecoder =
    D.map2 Location
        (D.field "lat" D.float)
        (D.field "lng" D.float)


receiveLocationDecoder : D.Decoder ReceiveLocation
receiveLocationDecoder =
    D.map2 ReceiveLocation
        (D.field "location" (D.maybe locationDecoder))
        (D.field "errorCode" (D.maybe D.int))


init : Flag -> ( Model, Cmd Msg )
init flag =
    ( Model flag.apiKey { lat = 0, lng = 0 } Nothing flag.supportGeolocation Nothing
    , Cmd.none
    )


type Msg
    = Refresh D.Value
    | Get3WA (Result Http.Error ConvertTo3WordAddress)



-- UPDATE

makeGet3WAUrl : APIKey -> Location -> String
makeGet3WAUrl apiKey location =
    String.concat
        [ "https://api.what3words.com/v3/convert-to-3wa?key="
        , apiKey
        , "&coordinates="
        , String.fromFloat location.lat
        , ","
        , String.fromFloat location.lng
        , "&language=ja&format=json"
        ]

type alias ThreeWordAddressSquare =
    { southwest : Location
    , northeast : Location
    }

type alias ConvertTo3WordAddress =
    { words : String
    , square : ThreeWordAddressSquare
    }

threeWordAddressSquareDecoder : D.Decoder ThreeWordAddressSquare
threeWordAddressSquareDecoder = 
    D.map2 ThreeWordAddressSquare
        (D.field "southwest" locationDecoder)
        (D.field "northeast" locationDecoder)

convertTo3WordAddressDecoder : D.Decoder ConvertTo3WordAddress
convertTo3WordAddressDecoder =
    D.map2 ConvertTo3WordAddress
        (D.field "words" D.string)
        (D.field "square" threeWordAddressSquareDecoder)

get3WordAddress : APIKey -> Location -> Cmd Msg
get3WordAddress apiKey location =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Accept" "application/json"
            ]
        , url = makeGet3WAUrl apiKey location
        , expect = Http.expectJson Get3WA convertTo3WordAddressDecoder
        , timeout = Nothing
        , tracker = Nothing
        , body = Http.emptyBody
        }

get3WAErrorHandler : Model -> Http.Error -> (Model, Cmd Msg)
get3WAErrorHandler model error =
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

compareLocation : Model -> Location -> (Model, Cmd Msg)
compareLocation model newLocation =
    let
        defaultAddress = 
            ThreeWordAddressSquare (Location 0 0) (Location 0 0)
                |> ConvertTo3WordAddress "" 
        address = 
            Maybe.withDefault defaultAddress model.threeWordAddress
        squareRange =
            address.square
    in
        if (squareRange.northeast.lat >= newLocation.lat) || (squareRange.northeast.lng >= newLocation.lng)
        then
            ( { model | location = newLocation}
            , get3WordAddress model.apiKey model.location
            )
        else
            if (squareRange.southwest.lat <= newLocation.lat) || (squareRange.southwest.lng <= newLocation.lng)
            then
                ( { model | location = newLocation }
                , get3WordAddress model.apiKey model.location
                )
            else 
                ( { model | location = newLocation }
                , Cmd.none
                )




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
                                    Maybe.withDefault { lat = 0, lng = 0 } status.location
                            in
                                compareLocation model newLocation

                Err _ ->
                    ( { model | error = Just "port error" }
                    , Cmd.none
                    )

        Get3WA (Ok resultJson) ->
            ( { model | threeWordAddress = Just resultJson }
            , Cmd.none
            )

        Get3WA (Err error) ->
            get3WAErrorHandler model error



-- SUBSCRIPTIONS

port receiveLocation : (D.Value -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
    receiveLocation Refresh



-- VIEW

menu : Html Msg
menu =
    Columns.columns Columns.columnsModifiers []
        [ Columns.column Columns.columnModifiers [] 
            [ text "My location"
            ]
        , Columns.column Columns.columnModifiers []
            [ text "Map"
            ]
        , Columns.column Columns.columnModifiers []
            [ text "Search"
            ]
        ]

view : Model -> Html Msg
view model =
    case model.error of
        Just errormsg ->
            div []
                [ CDN.stylesheet
                , div [] [ text errormsg ]
                , div []
                    (if model.geolocationAPIEnable then
                        [ text "Geolocation API: enabled" ]

                     else
                        [ text "Geolocation API: disabled" ]
                    )
                ]

        Nothing ->
            let
                defaultAddress = ThreeWordAddressSquare (Location 0 0) (Location 0 0)
                            |> ConvertTo3WordAddress ""
                address = Maybe.withDefault defaultAddress model.threeWordAddress
            in
                div []
                    [ div [] [ text ("latitude: " ++ String.fromFloat model.location.lat) ]
                    , div [] [ text ("longitude: " ++ String.fromFloat model.location.lng) ]
                    , div [] [ text ("3 Word Address: " ++ address.words) ]
                    , div []
                        (if model.geolocationAPIEnable then
                            [ text "Geolocation API: enabled" ]

                        else
                            [ text "Geolocation API: disabled" ]
                        )
                    , menu
                    ]
