%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% �ַ�������
%% 2345�˿ڸ�������client�� client������֮�󣬵ȴ�server������Ϣ
%% 2346�˿ڸ���������Ϣ�������򣬽�����Ϣ��Ȼ��ת�������е�cient
%% msv:start(). ������������
%% msv:client_connect("abcd"). �ͻ������ӡ�
%% msv:sms_send("U:444", term_to_binary("haha")). ��
%% Socket_sms = msv:sms_connect(). ��Ϣ�����ӡ�
%% msv:message_send(Socket_sms, "abcd").  ������Ϣ����
%% msv:message_send("abcd").  ������Ϣ����
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(msv).
-export([start/0, sms_send/1, sms_send/2]).
-export([sms_connect/0, message_send/2, message_send/1, message_u_send/3, message_u_send/2]).
-export([client_connect/1]).
-export([test/2]).

%% ��������������ʼ�������б������ͻ��˼����˿ڣ�������Ϣ�˼����˿ڣ�
start() ->
	init(),
	start_cient_listen(),
	start_sms_listen().

%%��ʼ�������������б�
init() ->
	Pid = spawn(fun() -> linklist_create() end),
	register(linklist, Pid).

%%���������б�
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


%%����client�ļ���
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




%%����SMS�ļ���
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

%�������û�������Ϣ Bin�������Ƹ�ʽ��
sms_send(Bin) ->
	L = ets:tab2list(tab_p_u),
	lists:foreach( fun({Pid,_}) -> Pid ! {message, Bin} end, L).

%�� User �û�������Ϣ Bin�������Ƹ�ʽ��
sms_send(User, Bin) ->
	case ets:lookup(tab_u_p, User) of
		[{User, Pid}] -> Pid ! {message, Bin};
		[] -> io:format("no user ~p~n", [User])
	end.




%%%%%%%%���Դ���%%%%%%%%
%%%%%%%%%%client%%%%%%%%%%%%%%%%%
%�ͻ������ӣ� Str������ �û�ID
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

%��Ϣ����������
sms_connect() ->
	{ok, Socket} = gen_tcp:connect("127.0.0.1", 2346, [binary, {packet, 4}]),
	Socket.

%��Ϣ����������
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

%��������ͻ������� C:������  P:ÿ����������Ҫ�����ӵ�����
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
