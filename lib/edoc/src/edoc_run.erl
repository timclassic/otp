%% =====================================================================
%% This library is free software; you can redistribute it and/or modify
%% it under the terms of the GNU Lesser General Public License as
%% published by the Free Software Foundation; either version 2 of the
%% License, or (at your option) any later version.
%%
%% This library is distributed in the hope that it will be useful, but
%% WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%%
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library; if not, write to the Free Software
%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
%% USA
%%
%% @copyright 2003 Richard Carlsson
%% @author Richard Carlsson <carlsson.richard@gmail.com>
%% @see edoc
%% @end 
%% =====================================================================

%% @doc Interface for calling EDoc from Erlang startup options.
%%
%% The following is an example of typical usage in a Makefile:
%% ```docs:
%%            erl -noshell -run edoc_run application "'$(APP_NAME)'" \
%%              '"."' '[{def,{vsn,"$(VSN)"}}]'
%% '''
%% (note the single-quotes to avoid shell expansion, and the
%% double-quotes enclosing the strings).
%%
%% <strong>New feature in version 0.6.9</strong>: It is no longer
%% necessary to write `-s init stop' last on the command line in order
%% to make the execution terminate. The termination (signalling success
%% or failure to the operating system) is now built into these
%% functions.

-module(edoc_run).

-export([file/1, application/1, packages/1, files/1, toc/1]).

-compile({no_auto_import,[error/1]}).

-import(edoc_report, [report/2, error/1]).


%% @spec application([string()]) -> none()
%%
%% @doc Calls {@link edoc:application/3} with the corresponding
%% arguments. The strings in the list are parsed as Erlang constant
%% terms. The list can be either `[App]', `[App, Options]' or `[App,
%% Dir, Options]'. In the first case {@link edoc:application/1} is
%% called instead; in the second case, {@link edoc:application/2} is
%% called.
%%
%% The function call never returns; instead, the emulator is
%% automatically terminated when the call has completed, signalling
%% success or failure to the operating system.

application(Args) ->
    F = fun () ->
		case parse_args(Args) of
		    [App] -> edoc:application(App);
		    [App, Opts] -> edoc:application(App, Opts);
		    [App, Dir, Opts] -> edoc:application(App, Dir, Opts);
		    _ ->
			invalid_args("edoc_run:application/1", Args)
		end
	end,
    run(F).

%% @spec files([string()]) -> none()
%%
%% @doc Calls {@link edoc:files/2} with the corresponding arguments. The
%% strings in the list are parsed as Erlang constant terms. The list can
%% be either `[Files]' or `[Files, Options]'. In the first case, {@link
%% edoc:files/1} is called instead.
%%
%% The function call never returns; instead, the emulator is
%% automatically terminated when the call has completed, signalling
%% success or failure to the operating system.

files(Args) ->
    F = fun () ->
		case parse_args(Args) of
		    [Files] -> edoc:files(Files);
		    [Files, Opts] -> edoc:files(Files, Opts);
		    _ ->
			invalid_args("edoc_run:files/1", Args)
		end
	end,
    run(F).

%% @spec packages([string()]) -> none()
%%
%% @doc Calls {@link edoc:application/2} with the corresponding
%% arguments. The strings in the list are parsed as Erlang constant
%% terms. The list can be either `[Packages]' or `[Packages, Options]'.
%% In the first case {@link edoc:application/1} is called instead.
%%
%% The function call never returns; instead, the emulator is
%% automatically terminated when the call has completed, signalling
%% success or failure to the operating system.

packages(Args) ->
    F = fun () ->
		case parse_args(Args) of
		    [Packages] -> edoc:packages(Packages);
		    [Packages, Opts] -> edoc:packages(Packages, Opts);
		    _ ->
			invalid_args("edoc_run:packages/1", Args)
		end
	end,
    run(F).

%% @hidden   Not official yet
toc(Args) ->
    F = fun () ->
 		case parse_args(Args) of
 		    [Dir, Paths] -> edoc:toc(Dir,Paths);
 		    [Dir, Paths, Opts] -> edoc:toc(Dir,Paths,Opts);
 		    _ ->
 			invalid_args("edoc_run:toc/1", Args)
 		end
 	end,
    run(F).


%% @spec file([string()]) -> none()
%%
%% @deprecated This is part of the old interface to EDoc and is mainly
%% kept for backwards compatibility. The preferred way of generating
%% documentation is through one of the functions {@link application/1},
%% {@link packages/1} and {@link files/1}.
%%
%% @doc Calls {@link edoc:file/2} with the corresponding arguments. The
%% strings in the list are parsed as Erlang constant terms. The list can
%% be either `[File]' or `[File, Options]'. In the first case, an empty
%% list of options is passed to {@link edoc:file/2}.
%%
%% The following is an example of typical usage in a Makefile:
%% ```$(DOCDIR)/%.html:%.erl
%%            erl -noshell -run edoc_run file '"$<"' '[{dir,"$(DOCDIR)"}]' \
%%              -s init stop'''
%%
%% The function call never returns; instead, the emulator is
%% automatically terminated when the call has completed, signalling
%% success or failure to the operating system.

file(Args) ->
    F = fun () ->
		case parse_args(Args) of
		    [File] -> edoc:file(File, []);
		    [File, Opts] -> edoc:file(File, Opts);
		    _ ->
			invalid_args("edoc_run:file/1", Args)
		end
	end,
    run(F).

-spec invalid_args(string(), list()) -> no_return().

invalid_args(Where, Args) ->
    report("invalid arguments to ~s: ~w.", [Where, Args]),
    shutdown_error().

run(F) ->
    wait_init(),
    case catch {ok, F()} of
	{ok, _} ->
	    shutdown_ok();
	{'EXIT', E} ->
	    report("edoc terminated abnormally: ~P.", [E, 10]),
	    shutdown_error();
	Thrown ->
	    report("internal error: throw without catch in edoc: ~P.",
		   [Thrown, 15]),
	    shutdown_error()
    end.

wait_init() ->
    case erlang:whereis(code_server) of
	undefined ->
	    erlang:yield(),
	    wait_init();
	_ ->
	    ok
    end.

%% When and if a function init:stop/1 becomes generally available, we
%% can use that instead of delay-and-pray when there is an error.

shutdown_ok() ->
    %% shut down emulator nicely, signalling "normal termination"
    init:stop().

shutdown_error() ->
    %% delay 1 second to allow I/O to finish
    receive after 1000 -> ok end,
    %% stop emulator the hard way with a nonzero exit value
    halt(1).

parse_args([A | As]) when is_atom(A) ->
    [parse_arg(atom_to_list(A)) | parse_args(As)];
parse_args([A | As]) ->
    [parse_arg(A) | parse_args(As)];
parse_args([]) ->
    [].

parse_arg(A) ->
    case catch {ok, edoc_lib:parse_expr(A, 1)} of
	{ok, Expr} ->
	    case catch erl_parse:normalise(Expr) of
		{'EXIT', _} ->
		    report("bad argument: '~s':", [A]),
		    exit(error);
		Term ->
		    Term
	    end;
	{error, _, D} ->
	    report("error parsing argument '~s'", [A]),
	    error(D),
	    exit(error)
    end.
