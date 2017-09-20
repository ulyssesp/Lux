import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Encode exposing (..)
import Json.Decode exposing (..)
import List exposing (..)
import Navigation exposing (..)
import Task exposing (..)
import WebSocket


main =
  Navigation.program SetLocation
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL

type alias Model =
  { messages : List String
  , votes : List String
  , passworded : Bool
  , location : Location
  }

type OutgoingMsg = Connecting | NextVote VoteType (List Int) | Reset | KitchenScene | MainReel
type IncomingMsg = Votes (List String) | PasswordResult Bool
type VoteType = Show | Film

voteType : VoteType -> String
voteType vt =
  case vt of
    Show -> "Show"
    Film -> "Film"

init : Location -> (Model, Cmd Msg)
init loc =
  (Model [] [] False loc, perform Send (Connecting |> encodeOutMsg |> Task.succeed))

encodeOutMsg : OutgoingMsg -> String
encodeOutMsg msg =
  encode 0 <|
    case msg of
      Connecting -> Json.Encode.object [("type", Json.Encode.string "connecting"), ("password", Json.Encode.string "password")]
      NextVote ty is-> Json.Encode.object [("type", Json.Encode.string <| "do" ++ voteType ty ++ "Vote"), ("votes", Json.Encode.list <| List.map Json.Encode.int is)]
      Reset -> Json.Encode.object [("type", Json.Encode.string "reset")]
      KitchenScene -> Json.Encode.object [("type", Json.Encode.string "kitchenScene")]
      MainReel -> Json.Encode.object [("type", Json.Encode.string "mainReel")]

decodeInMsg : String -> Result String IncomingMsg
decodeInMsg msg =
  let
    decodeVotes = Json.Decode.map Votes (field "votes" <| Json.Decode.list Json.Decode.string)
    decodePassResult = Json.Decode.map PasswordResult (field "success" <| Json.Decode.bool)
    decodeAll ty =
      case ty of
        "vote" -> decodeVotes
        "password" -> decodePassResult
        _ -> Json.Decode.fail "Message type wrong"
  in
    field "type" Json.Decode.string |> Json.Decode.andThen decodeAll |> flip decodeString msg


-- UPDATE

type Msg
  = Send String
  | NewMessage String
  | SetLocation Location

wsloc : Location -> String
wsloc loc = "ws://" ++ loc.hostname ++ ":9160"

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Send wsmsg ->
      (model, WebSocket.send (wsloc model.location) wsmsg)

    SetLocation loc ->
      ({ model | location = loc }, Cmd.none)

    NewMessage str ->
      case decodeInMsg str of
        Ok (Votes vts) ->
          ({ model | votes = vts }, Cmd.none)

        Ok (PasswordResult ps) ->
          ({ model | passworded = ps }, Cmd.none)

        _ ->
          ({ model | messages = str :: model.messages }, Cmd.none)


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen (wsloc model.location) NewMessage


-- VIEW

view : Model -> Html Msg
view model =
  div [] <|
    [ div [] (List.map viewMessage model.messages)
    , button [onClick (Send <| encodeOutMsg Reset)] [text "Reset"]
    , button [onClick (Send <| encodeOutMsg KitchenScene)] [text "Kitchen Scene"]
    , button [onClick (Send <| encodeOutMsg MainReel)] [text "MainReel"]
    , button [onClick (Send <| encodeOutMsg <| NextVote Show [0, 1, 2] )] [text "Show Vote 1"]
    , button [onClick (Send <| encodeOutMsg <| NextVote Film [1, 2, 3, 4, 9] )] [text "Film Vote 1"]
    , button [onClick (Send <| encodeOutMsg <| NextVote Show [2, 1, 0] )] [text "Show Vote 2"]
    , button [onClick (Send <| encodeOutMsg <| NextVote Film [1, 2, 3, 4, 5, 9] )] [text "Film Vote 2"]
    , button [onClick (Send <| encodeOutMsg <| NextVote Film [6, 7, 8] )] [text "Aspect ratios"]
    ] ++ indexedMap (\i t -> p [] [text t]) model.votes


viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]
