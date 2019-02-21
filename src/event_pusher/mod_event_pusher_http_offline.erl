-module(mod_event_pusher_http_offline).

-behaviour(mod_event_pusher_http).

%% API
-export([should_make_req/6, prepare_body/7, prepare_headers/7]).

-include("mongoose.hrl").
-include("jlib.hrl").

%% @doc This function determines whether to send http notification or not.
%% Can be reconfigured by creating a custom module implementing should_make_req/3
%% and adding it to mod_event_pusher_http settings as {callback_module}
%% Default behaviour is to send all chat messages with non-empty body.
should_make_req(_Acc, in, _Packet, _From, _To, _Opts) ->
    false;
should_make_req(Acc, out, Packet, From, To, _Opts) ->
    Type = exml_query:attr(Packet, <<"type">>, <<>>),
    Body = exml_query:path(Packet, [{element, <<"body">>}, cdata], <<>>),
    should_make_req_type(Acc, Type, Body, From, To).

should_make_req_type(_Acc, <<"chat">>, Body, _From, To) when Body /= <<"">> ->
    user_is_offline(To);
should_make_req_type(_Acc, <<"groupchat">>, Body, _From, To) when Body /= <<"">> ->
    ?INFO_MSG("Should make req from ~s to ~s: ~s", [
        jid:to_binary(_From),
        jid:to_binary(To),
        ejabberd_auth:is_user_exists(To#jid.luser, To#jid.lserver) and user_is_offline(To)
    ]),
    ejabberd_auth:is_user_exists(To#jid.luser, To#jid.lserver) and user_is_offline(To);
should_make_req_type(_Acc, _, _, _, _) ->
    false.

user_is_offline(To) ->
  ejabberd_sm:is_offline(To).

prepare_body(_Acc, _Dir, Host, Message, Sender, Receiver, _Opts) ->
    cow_qs:qs([{<<"author">>, jid:to_binary(Sender)},
        {<<"server">>, Host}, {<<"receiver">>, Receiver}, {<<"message">>, Message}]).

prepare_headers(_Acc, _Dir, _Host, _Sender, _Receiver, _Message, _Opts) ->
    [{<<"Content-Type">>, <<"application/x-www-form-urlencoded">>}].
