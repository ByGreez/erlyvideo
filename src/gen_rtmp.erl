  %%%---------------------------------------------------------------------------------------
%%% @author     Roberto Saccon <rsaccon@gmail.com> [http://rsaccon.com]
%%% @author     Stuart Jackson <simpleenigmainc@gmail.com> [http://erlsoft.org]
%%% @author     Luke Hubbard <luke@codegent.com> [http://www.codegent.com]
%%% @copyright  2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%% @doc        Generalized RTMP application behavior module
%%% @reference  See <a href="http://erlyvideo.googlecode.com" target="_top">http://erlyvideo.googlecode.com</a> for more information
%%% @end
%%%
%%%
%%% The MIT License
%%%
%%% Copyright (c) 2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%
%%%---------------------------------------------------------------------------------------
-module(gen_rtmp).
-author('rsaccon@gmail.com').
-author('simpleenigmainc@gmail.com').
-author('luke@codegent.com').
-include("../include/ems.hrl").

-export([connect/3,createStream/3,play/3,deleteStream/3,closeStream/3,pause/3,stop/3,publish/3]).

-export([behaviour_info/1]).


%%-------------------------------------------------------------------------
%% @spec (Callbacks::atom()) -> CallBackList::list()
%% @doc  List of require funcations in a RTMP application
%% @hidden
%% @end
%%-------------------------------------------------------------------------
behaviour_info(callbacks) -> [{createStream,3},{play,3},{stop,3},{pause,3},{deleteStream,3},{closeStream,3},{publish,3},{live,3},{append,3}];
behaviour_info(_Other) -> undefined.


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a connect command and responds
%% @end
%%-------------------------------------------------------------------------
connect(From, AMF, Channel) ->
    ?D("invoke - connect"),   
    NewAMF = AMF#amf{
        command = '_result', 
        id = 1, %% muriel: dirty too, but the only way I can make this work
        type = invoke,
        args= [null,
            [{level, "status"}, 
            {code, "NetConnection.Connect.Success"}, 
            {description, "Connection succeeded."}]]},
    gen_fsm:send_event(From, {send, {Channel,NewAMF}}).


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a createStream command and responds
%% @end
%%-------------------------------------------------------------------------
createStream(From, AMF, Channel) -> 
    ?D("invoke - createStream"), 
    _Type = invoke,  %% SimpleEnigma: Cleaned up this lien to prevent error message when compiling
    Id = 1, %% rsaccon: dirty temporary hack, because the line below does not work
    %%Id = gen_fsm:sync_send_event(From, next_stream_id),  %% rsaccon: why the hell is this not working !!??????!!!     
    NewAMF = AMF#amf{
    	command = '_result', 
    	args = [null, Id]},
    gen_fsm:send_event(From, {send, {Channel,NewAMF}}).


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a deleteStream command and responds
%% @end
%%-------------------------------------------------------------------------
deleteStream(_From, _AMF, _Channel) ->  
    ?D("invoke - deleteStream").


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a play command and responds
%% @end
%%-------------------------------------------------------------------------
play(From, AMF, Channel) -> 
    ?D("invoke - play"),
    NextChannel = Channel#channel{id=4},
    [_Null,{string,Name}] = AMF#amf.args,
    NewAMF = AMF#amf{
        command = 'onStatus', 
        args= [null,[{level, "status"}, 
                    {code, "NetStream.Play.Reset"}, 
                    {description, "Resetting NetStream."},
                    {details, Name},
                    {clientid, NextChannel#channel.stream}]]},
    gen_fsm:send_event(From, {send, {NextChannel,NewAMF}}),
    NewAMF2 = AMF#amf{
        command = 'onStatus', 
        args= [null,[{level, "status"}, 
                    {code, "NetStream.Play.Start"}, 
                    {description, "Start playing."},
                    {details, Name},
                    {clientid, NextChannel#channel.stream}]]},
    gen_fsm:send_event(From, {send, {NextChannel,NewAMF2}}),
    gen_fsm:send_event(From, {play, Name, NextChannel#channel.stream}).


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a pause command and responds
%% @end
%%-------------------------------------------------------------------------
pause(From, _AMF, _Channel) -> 
    ?D("invoke - pause"),
    gen_fsm:send_event(From, {pause}). 


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a publish command and responds
%% @end
%%-------------------------------------------------------------------------
publish(From, AMF, _Channel) -> 
    ?D("invoke - publish"),
    Args = AMF#amf.args,
    case Args of
        [{null,null},{string,Name},{string,Action}] ->
            case list_to_atom(Action) of
                record -> 
                    ?D({"Publish - Action - record",Name}),
                    gen_fsm:send_event(From, {publish, record, Name});
                append -> 
                     ?D({"Publish - Action - append",Name}),
                     gen_fsm:send_event(From, {publish, append, Name});
                live -> 
                    ?D({"Publish - Action - live",Name}),
                    gen_fsm:send_event(From, {publish, live, Name});
                _OtherAction -> 
                    ?D({"Publish Ignoring - ", _OtherAction})
            end;
		[{null,null},{string,Name}] -> % second arg is optional
			?D({"Publish - Action - live",Name}),
            gen_fsm:send_event(From, {publish, live, Name});
        _ -> ok
    end. 


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a stop command and responds
%% @end
%%-------------------------------------------------------------------------
stop(From, _AMF, _Channel) -> 
    ?D("invoke - stop"),
    gen_fsm:send_event(From, {stop}). 

%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a closeStream command and responds
%% @end
%%-------------------------------------------------------------------------
closeStream(From, _AMF, _Channel) ->
    ?D("invoke - closeStream"),
    gen_fsm:send_event(From, {stop}). 
