%%% @author     Roberto Saccon <rsaccon@gmail.com> [http://rsaccon.com]
%%% @author     Stuart Jackson <simpleenigmainc@gmail.com> [http://erlsoft.org]
%%% @author     Luke Hubbard <luke@codegent.com> [http://www.codegent.com]
%%% @copyright  2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%% @doc        Supervisor module
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
-module(ems_sup).
-author('rsaccon@gmail.com').
-author('simpleenigmainc@gmail.com').
-author('luke@codegent.com').
-include("../include/ems.hrl").
-behaviour(supervisor).

-export ([init/1,start_link/0]).
-export ([start_client/0]).
-export ([get_app_env/1,get_app_env/2]).

start_link() ->
	ListenPort = get_app_env(listen_port, ?RTMP_PORT),
	FSM = get_app_env(default_fsm, ems_fsm),
	supervisor:start_link({local, ?MODULE}, ?MODULE, [ListenPort, FSM]).


%%--------------------------------------------------------------------
%% @spec (List::list()) -> any()
%% @doc Initialize application
%% @end 
%%--------------------------------------------------------------------
init([Port, Module]) ->
    {ok,
        {_SupFlags = {one_for_one, ?MAX_RESTART, ?MAX_TIME},
            [ % EMS Cluster
			  {   ems_cluster,
		          {ems_cluster, start, []},
		          permanent,
		          1000,
		          worker,
		          [ems_cluster]
		      },
              % EMS Listener
              {   ems_sup,                                 % Id       = internal id
                  {ems_server,start_link,[Port,Module]},   % StartFun = {M, F, A}
                  permanent,                               % Restart  = permanent | transient | temporary
                  2000,                                    % Shutdown = brutal_kill | int() >= 0 | infinity
                  worker,                                  % Type     = worker | supervisor
                  [ems_server]                             % Modules  = [Module] | dynamic
              },
              % EMS instance supervisor
              {   ems_client_sup,
                  {supervisor,start_link,[{local, ems_client_sup}, ?MODULE, [Module]]},
                  permanent,                               % Restart  = permanent | transient | temporary
                  infinity,                                % Shutdown = brutal_kill | int() >= 0 | infinity
                  supervisor,                              % Type     = worker | supervisor
                  []                                       % Modules  = [Module] | dynamic
              }
            ]
        }
    };
init([Module]) ->
    {ok,
        {_SupFlags = {simple_one_for_one, ?MAX_RESTART, ?MAX_TIME},
            [
              % TCP Client
              {   undefined,                               % Id       = internal id
                  {Module,start_link,[]},                  % StartFun = {M, F, A}
                  temporary,                               % Restart  = permanent | transient | temporary
                  2000,                                    % Shutdown = brutal_kill | int() >= 0 | infinity
                  worker,                                  % Type     = worker | supervisor
                  []                                       % Modules  = [Module] | dynamic
              }
            ]
        }
    }.


%%----------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @spec () -> any()
%% @doc A startup function for spawning new client connection handling FSM.
%% To be called by the TCP listener process.
%% @end 
%%--------------------------------------------------------------------
start_client() -> supervisor:start_child(ems_sup, []).



%%--------------------------------------------------------------------
%% @spec (Opt::atom()) -> any()
%% @doc Gets application enviroment variable. User defined varaibles in 
%% .config file override application default varabiles. Default [].
%% @end 
%%--------------------------------------------------------------------
get_app_env(Opt) -> get_app_env(Opt, []).
%%--------------------------------------------------------------------
%% @spec (Opt::atom(), Default::any()) -> any()
%% @doc Gets application enviroment variable. Returns Default if no 
%% varaible named Opt is found. User defined varaibles in .config file
%% override application default varabiles.
%% @end 
%%--------------------------------------------------------------------
get_app_env(Opt, Default) ->
	case lists:keysearch(?APPLICATION, 1, application:loaded_applications()) of
		false -> application:load(?APPLICATION);
		_ -> ok
	end,
	case application:get_env(?APPLICATION, Opt) of
	{ok, Val} -> Val;
	_ ->
		case init:get_argument(Opt) of
		[[Val | _]] -> Val;
		error		-> Default
		end
	end.
