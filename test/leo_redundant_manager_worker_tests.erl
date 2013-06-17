%%======================================================================
%%
%% Leo Redundant Manager
%%
%% Copyright (c) 2012-2013 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%======================================================================
-module(leo_redundant_manager_worker_tests).
-author('Yosuke Hara').

-include("leo_redundant_manager.hrl").
-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% TEST FUNCTIONS
%%--------------------------------------------------------------------
-ifdef(EUNIT).

redundant_manager_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} || T <- [fun suite_/1
                          ]]}.

setup() ->
    application:start(crypto),

    catch ets:delete('leo_members'),
    catch ets:delete('leo_ring_cur'),
    catch ets:delete('leo_ring_prv'),

    leo_misc:init_env(),
    leo_misc:set_env(leo_redundant_manager, 'server_type', 'gateway'),
    {ok, Pid} = leo_redundant_manager_sup:start_link(gateway),
    leo_redundant_manager_api:set_options(
      [{n, 3},{r, 1}, {w ,2},{d, 2},{bit_of_ring, 128},{level_2, 0}]),
    leo_redundant_manager_api:attach('node_0@127.0.0.1'),
    leo_redundant_manager_api:attach('node_1@127.0.0.1'),
    leo_redundant_manager_api:attach('node_2@127.0.0.1'),
    leo_redundant_manager_api:attach('node_3@127.0.0.1'),
    leo_redundant_manager_api:attach('node_4@127.0.0.1'),
    leo_redundant_manager_api:create(),
    timer:sleep(1500),
    Pid.

teardown(Pid) ->
    timer:sleep(200),
    exit(Pid, normal),
    application:stop(crypto),
    ok.

suite_(_) ->
    RingWorker1 = poolboy:checkout('ring_worker_pool'),
    {ok, #vnodeid_nodes{id = 1,
                        vnode_id_from = 0,
                        nodes = N0}} = leo_redundant_manager_worker:first(RingWorker1, 'leo_ring_cur'),
    {ok, #redundancies{nodes = N1}} = leo_redundant_manager_worker:lookup(
                                        RingWorker1, 'leo_ring_cur', 0),
    {ok, #redundancies{nodes = N2}} = leo_redundant_manager_worker:lookup(
                                        RingWorker1, 'leo_ring_cur', 1264314306571079495751037749109419166),
    {ok, #redundancies{nodes = N3}} = leo_redundant_manager_worker:lookup(
                                        RingWorker1, 'leo_ring_cur', 3088066518744027498382227205172020754),
    {ok, #redundancies{nodes = N4}} = leo_redundant_manager_worker:lookup(
                                        RingWorker1, 'leo_ring_cur', 4870818527799149765629747665733758595),
    {ok, #redundancies{nodes = N5}} = leo_redundant_manager_worker:lookup(
                                        RingWorker1, 'leo_ring_cur', 5257965865843856950061366315134191522),
    {ok, #redundancies{nodes = N6}} = leo_redundant_manager_worker:lookup(
                                        RingWorker1, 'leo_ring_cur', 340282366920938463463374607431768211456),
    {ok, #vnodeid_nodes{id = 840,
                        nodes = N7}} = leo_redundant_manager_worker:last(RingWorker1, 'leo_ring_cur'),

    ?assertEqual(3, length(N0)),
    ?assertEqual(3, length(N1)),
    ?assertEqual(3, length(N2)),
    ?assertEqual(3, length(N3)),
    ?assertEqual(3, length(N4)),
    ?assertEqual(3, length(N5)),
    ?assertEqual(3, length(N6)),
    ?assertEqual(3, length(N7)),

    Seq  = lists:seq(1, 10000),
    St = leo_date:clock(),
    lists:foreach(fun(_) ->
                          AddrId = leo_redundant_manager_chash:vnode_id(128, crypto:rand_bytes(64)),
                          {ok, #redundancies{nodes = N8}} =
                              leo_redundant_manager_worker:lookup(
                                RingWorker1, 'leo_ring_cur', AddrId),
                          ?assertEqual(3, length(N8))
                  end, Seq),
    End = leo_date:clock(),
    ?debugVal((End - St) / 1000),
    poolboy:checkin('ring_worker_pool', RingWorker1),
    ok.

-endif.