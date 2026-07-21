#!/bin/bash
ERL_FLAGS='-name sipalerts@127.0.0.1' rebar3 as test eunit -m alert_manager_tests