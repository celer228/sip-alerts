-module(alert_core_utils).

-export([override_module/2]).

override_module(Mod, Default) ->
    case Mod of
        undefined -> Default;
        OverridenMod -> OverridenMod
    end.