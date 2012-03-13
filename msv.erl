%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 分发服务器
%% 2345端口负责连接client， client连接上之后，等待server发送消息
%% 2346端口负责连接消息产生程序，接收消息，然后转发给所有的cient
%% msv:start(). 启动服务器。
%% msv:client_connect("abcd"). 客户端链接。
%% msv:sms_send("U:444", term_to_binary("haha")). 。
%% Socket_sms = msv:sms_connect(). 消息端链接。
%% msv:message_send(Socket_sms, "abcd").  发送消息函数
%% msv:message_send("abcd").  发送消息函数
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(msv).
-export([start/0, sms_send/1, sms_send/2]).
-export([sms_connect/0, message_send/2, message_send/1, message_u_send/3, message_u_send/2]).
-export([client_connect/1]).
-export([test/2]).

%% 启动服务器（初始化链接列表、创建客户端监听端口，创建消息端监听端口）
start() ->
	init(),
	start_cient_listen(),
	start_sms_listen().

%%初始化，设置链接列表
init() ->
	Pid = spawn(fun() -> linklist_create() end),
	register(linklist, Pid).

%%创建链接列表
linklist_create() ->
	ets:new(tab_p_u, [set, protected, named_table]),
	ets:new(tab_u_p, [set, protected, named_table]),
	linklist_change().

linklist_change() ->
	receive
		{add, Pid, User} ->
			ets:insert(tab_p_u, {Pid, User}),
			ets:insert(tab_u_p, {User, Pid}),
			linklist_change();
		{del, Pid} ->
			[{Pid, User}] = ets:lookup(tab_p_u, Pid),
			ets:delete(tab_p_u, Pid),
			ets:delete(tab_u_p, User),
			linklist_change()
	end.


%%开启client的监听
start_cient_listen() ->
	{ok, Listen_c} = gen_tcp:listen(2345, [binary, {packet, 4}, {reuseaddr, true}, {active, once}]),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	spawn(fun() -> client_content(Listen_c) end),
	io:format("cient_listen ok ~n").

client_content(Listen_c) ->
	{ok, Socket} = gen_tcp:accept(Listen_c),
	spawn(fun() -> client_content(Listen_c) end),
	client_loop(Socket).

client_loop(Socket) ->
	receive
		{tcp, Socket, Bin} ->
			inet:setopts(Socket, [{active, once}]),
			Str = binary_to_term(Bin),
			%io:format("regiest uid ~p~n", [Str]),
			linklist ! {add, self(), Str},
			%gen_tcp:send(Socket, term_to_binary([Str, " ok"])),
			client_loop(Socket);
		{tcp_closed, Socket} ->
			%io:format("cient close ~n"),
			linklist ! {del, self()};
		{message, Bin} ->
			%io:format("send message ~n"),
			gen_tcp:send(Socket, Bin),
			client_loop(Socket)
	end.




%%开启SMS的监听
start_sms_listen() ->
	{ok, Listen_s} = gen_tcp:listen(2346, [binary, {packet, 4}, {reuseaddr, true}, {active, once}]),
	spawn(fun() -> sms_content(Listen_s) end),
	spawn(fun() -> sms_content(Listen_s) end),
	io:format("sms_listen ok ~n").

sms_content(Listen_s) ->
	{ok, Socket} = gen_tcp:accept(Listen_s),
	spawn(fun() -> sms_content(Listen_s) end),
	sms_loop(Socket).
	
sms_loop(Socket) ->
	receive
		{tcp, Socket, Bin} ->
			inet:setopts(Socket, [{active, once}]),
			case binary_to_term(Bin) of
				{User, Msg} -> sms_send(User, term_to_binary(Msg));
				_ -> sms_send(Bin)
			end,
			sms_send(Bin),
			sms_loop(Socket);
		{tcp_closed, Socket} ->
			io:format("sms close ~n")
	end.

%对所有用户发送消息 Bin（二进制格式）
sms_send(Bin) ->
	L = ets:tab2list(tab_p_u),
	lists:foreach( fun({Pid,_}) -> Pid ! {message, Bin} end, L).

%对 User 用户发送消息 Bin（二进制格式）
sms_send(User, Bin) ->
	case ets:lookup(tab_u_p, User) of
		[{User, Pid}] -> Pid ! {message, Bin};
		[] -> io:format("no user ~p~n", [User])
	end.




%%%%%%%%测试代码%%%%%%%%
%%%%%%%%%%client%%%%%%%%%%%%%%%%%
%客户端连接， Str参数是 用户ID
client_connect(Str) ->
	{ok, Socket} = gen_tcp:connect("127.0.0.1", 2345, [binary, {packet, 4}]),
	ok = gen_tcp:send(Socket, term_to_binary(Str)),
	client_revieve_loop(Socket).

client_revieve_loop(Socket) ->
	receive
		{tcp, Socket, _} ->
			io:format("client recieve binary = ~p~n", [Bin]),
			Val = binary_to_term(Bin),
			io:format("Client result = ~p~n", [Val]),
			client_revieve_loop(Socket)
	end.

%%%%%%%%%%sms%%%%%%%%%%%%%%%%%

%消息服务器连接
sms_connect() ->
	{ok, Socket} = gen_tcp:connect("127.0.0.1", 2346, [binary, {packet, 4}]),
	Socket.

%消息服务器连接
message_send(Socket, Str) ->
	ok = gen_tcp:send(Socket, term_to_binary(Str)).

message_send(Str) ->
	{ok, Socket} = gen_tcp:connect("127.0.0.1", 2346, [binary, {packet, 4}]),
	ok = gen_tcp:send(Socket, term_to_binary(Str)),
	gen_tcp:close(Socket).

message_u_send(User, Str) ->
	{ok, Socket} = gen_tcp:connect("127.0.0.1", 2346, [binary, {packet, 4}]),
	ok = gen_tcp:send(Socket, term_to_binary({User, Str})),
	gen_tcp:close(Socket).

message_u_send(Socket, User, Str) ->
	ok = gen_tcp:send(Socket, term_to_binary({User, Str})).

%开启多个客户端链接 C:并发数  P:每个并发链接要打开链接的数量
test(C, P) -> 
	io:format("test starting~n"),
	statistics(wall_clock),
	for(0, C, P).

for(Max, Max, _) ->  
	io:format("start thread ~p~n", [Max]);  
for(First, Max, P) ->  
	spawn(fun() -> test_connect( First, 1,  P) end),
	for(First + 1, Max, P).

test_connect(First, Second, Count) ->
	{ok, Socket} = gen_tcp:connect("127.0.0.1", 2345, [binary, {packet, 4}]),
	U1 = string:concat("U:", erlang:integer_to_list(First)),
	U2 = string:concat(":", erlang:integer_to_list(Second)),
	U  = string:concat(U1, U2),
	ok = gen_tcp:send(Socket, term_to_binary(U)),
	case Second < Count of
		true  -> spawn(fun() -> test_connect( First, Second+1,  Count) end);
		false ->
			{_, Time} = statistics(wall_clock),
			io:format("finish thread ~p(~p)~n", [First, Time])
	end,
	client_revieve_loop(Socket).
