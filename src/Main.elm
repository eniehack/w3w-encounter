-- SPDX-License-Identifier: Apache-2.0 OR AGPL-3.0-only
port module Main exposing (main)

import Browser exposing (element)
import Html exposing (Html, div, text, nav, a, p, button)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Http
import Json.Decode as D

type alias APIKey =
    String


type alias Flag =
    { apiKey : APIKey
    , supportGeolocation : Bool
    , supportClipboard : Bool
    , supportWebShareAPI : Bool
    }


type alias Location =
    { lat : Float
    , lng : Float
    }

type alias ReceivedLocation =
    { location : Maybe Location
    , errorCode : Maybe Int
    }

type alias Converted3WordAddress =
    { words : String
    , square : ThreeWordAddressSquare
    }

type ThreeWordAddress
    = Received Converted3WordAddress
    | NotReceived
    | Init
    | Error Error

type Error
    = HttpError Http.Error
    | GeolocationAPIPermissionDenied
    | GeolocationAPIPositionUnavailable
    | GeolocationAPITimeout
    | None
    | UnknownError
    | PortError

type alias WhichIsWebAPIEnabled =
    { geolocationAPI : Bool
    , webshareAPI : Bool
    , clipboardAPI : Bool
    }

type alias Model =
    { apiKey : APIKey
    , location : Location
    , error : Error
    , whichIsWebAPIEnabled : WhichIsWebAPIEnabled
    , threeWordAddress : ThreeWordAddress
    }

locationDecoder : D.Decoder Location
locationDecoder =
    D.map2 Location
        (D.field "lat" D.float)
        (D.field "lng" D.float)

receivedLocationDecoder : D.Decoder ReceivedLocation
receivedLocationDecoder =
    D.map2 ReceivedLocation
        (D.field "location" (D.maybe locationDecoder))
        (D.field "errorCode" (D.maybe D.int))

init : Flag -> ( Model, Cmd Msg )
init flag =
    ( Model flag.apiKey { lat = 0, lng = 0 } None ( WhichIsWebAPIEnabled flag.supportGeolocation flag.supportWebShareAPI flag.supportClipboard) Init
    , Cmd.none
    )


type Msg
    = ExtractResponseGetThreeWordAddress (Result Http.Error Converted3WordAddress)
    | CopyToClipboardThreeWordAddress 
    | ExtractGeolocationData D.Value
    | ShareOverWebShareAPI

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

threeWordAddressSquareDecoder : D.Decoder ThreeWordAddressSquare
threeWordAddressSquareDecoder = 
    D.map2 ThreeWordAddressSquare
        (D.field "southwest" locationDecoder)
        (D.field "northeast" locationDecoder)

converted3WordAddressDecoder : D.Decoder Converted3WordAddress
converted3WordAddressDecoder =
    D.map2 Converted3WordAddress
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
        , expect = Http.expectJson ExtractResponseGetThreeWordAddress converted3WordAddressDecoder
        , timeout = Nothing
        , tracker = Nothing
        , body = Http.emptyBody
        }

changedThreeWordAddressLocation : Model -> Location -> Bool
changedThreeWordAddressLocation model newLocation =
    case model.threeWordAddress of
        Received threeWordAddress ->
            if (threeWordAddress.square.northeast.lat >= newLocation.lat) && (newLocation.lat >= threeWordAddress.square.southwest.lat) 
            then
                False
            else
                if (threeWordAddress.square.northeast.lng >= newLocation.lng) && (newLocation.lng >= threeWordAddress.square.southwest.lng)
                then
                    False
                else 
                    True
        Init ->
            True
        NotReceived ->
            True
        Error _ ->
            False
        

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of

        ExtractResponseGetThreeWordAddress (Ok resultJson) ->
            ( { model | threeWordAddress = Received resultJson }
            , Cmd.none
            )

        ExtractResponseGetThreeWordAddress (Err error) ->
            ( { model | error = HttpError error }
            , Cmd.none
            )

        CopyToClipboardThreeWordAddress ->
            case model.threeWordAddress of
                Received square ->
                    ( model
                    , sendCopyToClipboardRequest square.words
                    )
                _ ->
                    ( model
                    , sendCopyToClipboardRequest ""
                    )
        ShareOverWebShareAPI ->
            case model.threeWordAddress of
                Received square ->
                    ( model
                    , sendShareOverWebShareAPIRequest square.words
                    )
                _ ->
                    ( model
                    , sendShareOverWebShareAPIRequest ""
                    )

        ExtractGeolocationData data ->
            let
                decodedData = D.decodeValue receivedLocationDecoder data
            in
                case decodedData of
                    Err _ ->
                        ( { model | error = PortError }
                        , Cmd.none 
                        )
                    Ok result ->
                        case result.errorCode of
                            Just 1 ->
                                ( { model | error = GeolocationAPIPermissionDenied }
                                , Cmd.none
                                )
                            Just 2 ->
                                ( { model | error = GeolocationAPIPositionUnavailable }
                                , Cmd.none
                                )
                            Just 3 ->
                                ( { model | error = GeolocationAPITimeout }
                                , Cmd.none
                                )
                            Just _ -> 
                                ( { model | error = UnknownError}
                                , Cmd.none
                                )

                            Nothing ->
                                case result.location of
                                    Just point ->
                                        if changedThreeWordAddressLocation model point
                                        then 
                                            ( { model | location = point }
                                            , get3WordAddress model.apiKey model.location
                                            )
                                        else
                                            ( { model | location = point }
                                            , Cmd.none
                                            )
                                
                                    Nothing ->
                                        ( { model | error = UnknownError }
                                        , Cmd.none
                                        )

-- SUBSCRIPTIONS


port receiveLocation : (D.Value -> msg) -> Sub msg
port sendCopyToClipboardRequest : String -> Cmd msg
port sendShareOverWebShareAPIRequest : String -> Cmd msg

subscriptions : Model -> Sub Msg
subscriptions model =
    receiveLocation ExtractGeolocationData



-- VIEW

navbar : Html Msg
navbar =
    nav [ class "navbar is-link is-fixed-bottom"]
    [ div [ class "navbar-brand" ]
        [ a [ class "navbar-item is-expanded is-block has-text-centered" ]
            [ p [ class "is-size-7" ]
                [ text "location" ]
            ]
        , a [ class "navbar-item is-expanded is-block has-text-centered" ]
            [ p [ class "is-size-7" ]
                [ text "Map" ]
            ]
        , a [ class "navbar-item is-expanded is-block has-text-centered" ]
            [ p [ class "is-size-7" ]
                [ text "About" ]
            ]
        ]
    ]

view : Model -> Html Msg
view model =
    case model.error of
        GeolocationAPIPermissionDenied ->
            div [] 
                [ div [] [ text "位置情報の取得に失敗しました。ブラウザに位置情報を共有するよう設定してみてください。もしくはスマートフォンのGPSがオフになっていませんか？" ]
                , navbar
                ]

        GeolocationAPIPositionUnavailable ->
            div [] 
                [ div [] [ text "位置情報の取得に失敗しました。スマートフォンのGPSがオフになっていませんか？" ]
                , navbar
                ]

        GeolocationAPITimeout ->
            div [] 
                [ div [] [ text "位置情報の取得に失敗しました。" ]
                , navbar
                ]

        UnknownError ->
            div [] 
                [ div [] [ text "予期しないエラーが発生しました。" ]
                , navbar
                ]
        
        PortError ->
            div [] 
                [ div [] [ text "予期しないエラーが発生しました。" ]
                , navbar
                ]

        HttpError _ ->
            div [] 
                [ div [] [ text "What3Words APIサーバーとの通信に失敗しました。" ]
                , navbar
                ]

        None ->
            case model.threeWordAddress of
                Received address ->
                    div []
                    [ div [] [ text ("latitude: " ++ String.fromFloat model.location.lat) ]
                    , div [] [ text ("longitude: " ++ String.fromFloat model.location.lng) ]
                    , if model.whichIsWebAPIEnabled.clipboardAPI
                        then 
                            div []
                            [ div [ onClick CopyToClipboardThreeWordAddress, class "is-size-4-mobile", class "has-text-weight-bold", class "has-text-justified" ] [ text address.words]
                            , div [ class "is-size-7" ] [ text "上記 3 Word Addressをクリックするとクリップボードにコピーされます。" ]
                            ]
                        else
                            div [ class "is-size-4-mobile", class "has-text-weight-bold", class "has-text-justified" ] [ text address.words ]
                    , a [ href (String.concat ["geo:", String.fromFloat model.location.lat, ",", String.fromFloat model.location.lng, "?z=19"]) ] [ text "地図アプリで開く"]
                    , if model.whichIsWebAPIEnabled.webshareAPI
                        then
                            div [] [ button [ onClick ShareOverWebShareAPI ] [ text "Share" ] ]
                        else
                            div [] []
                    , navbar
                    ]
            
                NotReceived ->
                    div []
                    [ div [] [ text ("latitude: " ++ String.fromFloat model.location.lat) ]
                    , div [] [ text ("longitude: " ++ String.fromFloat model.location.lng) ]
                    , div [] [ text "Please wait..." ]
                    ]

                Init ->
                    if model.whichIsWebAPIEnabled.geolocationAPI
                    then
                        div []
                        [ div [] [ text ("latitude: " ++ String.fromFloat model.location.lat) ]
                        , div [] [ text ("longitude: " ++ String.fromFloat model.location.lng) ]
                        , div [] [ text "Please wait..." ]
                        , navbar
                        ]
                    else
                        div []
                        [ div [] [ text "このブラウザは位置情報にアクセスできません。"]
                        , navbar
                        ]
                
                _ ->
                    div [] 
                        [ div [] [ text "What3Words APIサーバーとの通信に失敗しました。" ]
                        , navbar
                        ]

main : Program Flag Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
