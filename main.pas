program PascalFlowchartng;
uses crt,dos;
const
    nvariants=3;
type
    CaretPos = integer;
    rec = record
        snode,enode: integer;
        n: string;
        expect: array[1..4] of string[20];
        l:integer;
    end;
    PStackElement = ^StackElement;
    StackElement = record
        value: rec;
        next, prev : PStackElement;
    end;
    PSuppStackElement = ^SuppStackElement;
    SuppStackElement = record
        value: integer;
        next, prev: PSuppStackElement;
    end;
var
    inputString: AnsiString;
    lexpos: CaretPos; {текущая позиция разбора}
    incomment,instring: boolean; {глобальные переменные используемые лексером - находимся в строке, находимся в комментарии}
    s: string; {текущая лексема}
    stack: PStackElement; {элементы стека rec для хранения списка ожидаемых элементов}
    suppStack,suppstack2: PSuppStackElement; {элементы стека integer для хранения указателей}
    n_n: integer; {текущий номер токена - используется при нумерации вершин в dot}
    currec: rec;
    Pcurrec: ^rec;
    accum: String; {аккумулятор токенов}
    run: boolean; {флаг начала разбора}
    t1:string;
    lflag1: boolean;
    { временные переменные }
    temp: String;
    tempi: integer;
{ возвращает строку без предшествующих и последующих пробелов, символов табуляции, CR, LF}
function trim(s:Ansistring):Ansistring;
var
    i,j:integer;
begin
    i:=1;
    j:=length(s);
    while (s[i] in [' ',#13, #10, #9]) do i:=i+1;
    while (s[j] in [' ',#13, #10, #9]) do j:=j-1;
    trim:=copy(s,i,(j-i)+1);
end;
{ возвращает подстроку inputString начиная с startpos, заканчивая endpos }
function substring(startpos,endpos:integer):AnsiString;
Var
    i:integer;
    buff:AnsiString;
begin
    buff:='';
    for i:=startpos to endpos do buff:=buff+inputString[i];
    substring:=buff;
end;
{ семейство функций stack_, оперирует со стеком ожидаемых элементов}
{ оперирует с stack(PStackElement)}
{ push - добавить с стек
  pop - вытолкнуть из стека, вернуть результат
  get - вернуть верхний элемент из стека, не выталкивая
  isempty - пуст ли стек
}
procedure stack_push(l:rec);
begin
    if stack=nil then
    begin
        new(stack);
        stack^.value:=l;
        stack^.prev:=nil;
        stack^.next:=nil;
    end
    else
    begin
        new(stack^.next);
        stack^.next^.value:=l;
        stack^.next^.prev:=stack;
        stack^.next^.next:=nil;
        stack:=stack^.next;
    end;
end;
function stack_pop():rec;
begin
    stack_pop:=stack^.value;
    if (stack^.prev<>nil) then stack:=stack^.prev;
    dispose(stack^.next);
end;
function stack_get():rec;
begin
    if stack<>nil then
        stack_get:=stack^.value;
end;
function stack_get(lev:integer):rec;
var
    t:PStackElement;
begin
    t:=stack;
    while lev>0 do
    begin
            t:=t^.prev;
            lev:=lev-1;
    end;
    stack_get:=t^.value;
end;
function stack_isempty():boolean;
begin
    stack_isempty:=(stack=nil){stack^.prev=nil};
end;
{ семейство функций suppstack_, оперирует со стеком точек "else"}
{ оперирует с suppstack(PSuppStackElement)}
function suppstack_isempty:boolean;
begin
    suppstack_isempty:=(suppstack=nil);
end;
procedure suppstack_update(l:integer);
begin
    if suppstack<>nil then
    begin
        suppstack^.value:=l;
    end
end;
procedure suppstack_push(l:integer);
begin
    if suppstack=nil then
    begin
        new(suppstack);
        suppstack^.value:=l;
        suppstack^.prev:=nil;
        suppstack^.next:=nil;
    end
    else
    begin
        new(suppstack^.next);
        suppstack^.next^.value:=l;
        suppstack^.next^.prev:=suppstack;
        suppstack^.next^.next:=nil;
        suppstack:=suppstack^.next;
    end;
end;
function suppstack_pop():integer;
var
        t: psuppstackelement;
begin
    if suppstack<>nil then
    begin
        t:=suppstack;
        suppstack_pop:=suppstack^.value;
        suppstack:=suppstack^.prev;
        dispose(t);
    end
    else
    begin
        suppstack_pop:=high(integer);
    end
end;
function suppstack_get():integer;
begin
    if suppstack<>nil then
        suppstack_get:=suppstack^.value;
end;


{ семейство функций suppstack2_, оперирует со стеком точек возврата "begin"}
{ оперирует с suppstack2(PStackElement)}
function suppstack2_isempty:boolean;
begin
    suppstack2_isempty:=(suppstack2=nil);
end;
procedure suppstack2_update(l:integer);
begin
    if suppstack2<>nil then
    begin
        suppstack2^.value:=l;
    end
end;
procedure suppstack2_push(l:integer);
begin
    if suppstack2=nil then
    begin
        new(suppstack2);
        suppstack2^.value:=l;
        suppstack2^.prev:=nil;
        suppstack2^.next:=nil;
    end
    else
    begin
        new(suppstack2^.next);
        suppstack2^.next^.value:=l;
        suppstack2^.next^.prev:=suppstack2;
        suppstack2^.next^.next:=nil;
        suppstack2:=suppstack2^.next;
    end;
end;
function suppstack2_pop():integer;
var
        t: psuppstackelement;
begin
    if suppstack2<>nil then
    begin
        t:=suppstack2;
        suppstack2_pop:=suppstack2^.value;
        suppstack2:=suppstack2^.prev;
        dispose(t);
    end
    else
    begin
        suppstack2_pop:=high(integer);
    end
end;
function suppstack2_get():integer;
begin
    if suppstack2<>nil then
        suppstack2_get:=suppstack2^.value;
end;

{ проверяет, находится ли строка в списке ожидаемых вариантов }
function invariants(s:string):boolean;
var
    i:integer;
begin
    invariants:=false;
    for i:=1 to nvariants do
        if stack_get().expect[i]=s then invariants:=true;
end;
{ лексер, делит ввод на токены(элементарные структуры языка) }
{ токены представляют собой ключевое слово, оператор, константу }
{ лексер правильно обрабатывает комментарии, многобуквенные операторы(<=, .., :=, etc), строки}
{ каждый раз при вызове, lexpos продвигается по данным }
function lex():AnsiString;
var
    tempst: String;
    was: integer;
    cont: boolean;
begin
    if (lexpos>=length(inputString)) then
    begin
        lex:='';
        exit;
    end;
    tempst:='';
    was:=0;
    while (inputString[lexpos] in [' ',#9,#10,#13]) do
    begin
        lexpos:=lexpos+1;
    end;
    while true do
    begin
        if inputString[lexpos]='{' then
        begin
            incomment:=true;
            lexpos:=lexpos+1;
            continue;
        end
        else if (incomment and (inputString[lexpos]='}')) then
        begin
            incomment:=false;
            lexpos:=lexpos+1;
            while (inputString[lexpos] in [' ',#9,#10,#13]) do
            begin
                lexpos:=lexpos+1;
            end;
            continue;
        end
        else if incomment then
        begin
            lexpos:=lexpos+1;
            continue;
        end;

        if inputString[lexpos]='''' then
            begin
                instring:=not instring;
                tempst:=tempst+inputString[lexpos];
                lexpos:=lexpos+1;
                if instring then continue else break;
            end;
        if instring then
        begin
               tempst:=tempst+inputString[lexpos];
            lexpos:=lexpos+1;
            continue;
        end;

        if (not (incomment or instring)) then
        begin
            if ((was<2) and (inputString[lexpos] in ['a'..'z','A'..'Z','0'..'9','_'])) then
            begin
                tempst:=tempst+inputString[lexpos];
                lexpos:=lexpos+1;
                was:=1;
            end
            else if ((was<>1) and not(inputString[lexpos] in [' ',#9,#13,#10,'a'..'z','A'..'Z','0'..'9','_'])) then
            begin
                tempst:=tempst+inputString[lexpos];
                cont:=false;
                case inputString[lexpos] of
                    '/': if (inputString[lexpos+1]='/') then cont:=true;
                    '.': if ((inputString[lexpos+1]='.')and(lexpos<length(inputString))) then cont:=true;
                    ':': if (inputString[lexpos+1]='=') then cont:=true;
                    '>': if (inputString[lexpos+1]='=') then cont:=true;
                    '<': if ((inputString[lexpos+1]='=') or (inputString[lexpos+1]='>')) then cont:=true;
                end;
                lexpos:=lexpos+1;
                if not cont then break;
                was:=2;
            end
            else break;
        end;
    end;
    lex:=tempst;
end;

begin
    clrscr;
    assign(input,'input.txt');
    assign(output,'output.txt');
    reset(input);
    rewrite(output);
    inputString:='';
    while (not eof(input)) do
    begin
        readln(input,temp);
        inputString:=inputString+#10+#13+Temp;
    end;
    close(input);
    assign(input,'con');
    reset(input);

    n_n:=0;
    lexpos:=1;
    s:=' ';
    writeln('Digraph G {');
    writeln('n_0[label="begin"];');
    writeln('n_0->n_1');
    while (s<>'') do
    begin
        s:=lex();
        if ((s<>'begin') and (not run)) then continue else run:=true;
        if (s='else') then lflag1:=true;
        if ((s=';') or (s='end')) then
        begin
            if (invariants(s)) then
            begin
                currec:=stack_pop();
                if (currec.n='else') then
                begin
                    if (suppstack_get<high(integer)) then writeln('n_',suppstack_pop(),'->n_',n_n,';');
                end;
                if (currec.n='then') then
                begin
                    writeln('n_',suppstack_pop(),'->n_',n_n+1,';');
                    n_n:=n_n+1;
                end;
                if ((stack_get.n='do')) then
                    begin
                        writeln('n_',n_n,'->n_',n_n+1,';');
                        writeln('n_',n_n+1,'[shape=invtrapezium,label=""];');
                        n_n:=n_n+1;
                    end;
                if (currec.n='until') then
                begin
                        writeln('n_',n_n,'->n_',n_n+1,';');
                        writeln('n_',n_n+1,'[shape=invtrapezium,label="',accum,'"];');
                        accum:='';
                        n_n:=n_n+1;
                end;
                while (invariants(currec.n)) do
                begin
                    currec:=stack_pop();

                if (currec.n='if') then
                begin
                    tempi:=suppstack2_pop();
                    if (tempi<high(integer)) then
                    begin
                        writeln('n_',tempi,'->n_',n_n,';');
                    end;
                end;
                end;
                if (currec.n='else') then
                begin
                	tempi:=suppstack2_pop();
                    if (tempi<high(integer)) then
                    begin
                        writeln('n_',tempi,'->n_',n_n+1,';');
                    end;
                	
                end;
            end;
            if (accum<>'') then
            begin
                if (not lflag1) then writeln('n_',n_n,'->n_',n_n+1,';');
                lflag1:=false;
                writeln('n_',n_n+1,'[shape=rectangle; label="',accum,'"];');
                accum:='';
                n_n:=n_n+1;
            end;
        end else if ((s='repeat') or (s='begin') or (s='else') or (s='to') or (s='downto') or (s='do') or (s='then') or (s='while') or (s='for') or (s='if') or (s='until')) then
        begin
            new(pcurrec);
            pcurrec^.snode:=n_n;
            pcurrec^.n:=s;
            pcurrec^.l:=lexpos;
            if (s='repeat') then
            begin
                pcurrec^.expect[1]:='until';
            end
            else if (s='until') then
            begin
                pcurrec^.expect[1]:=';';
            end
            else if (s='begin') then
            begin
                pcurrec^.expect[1]:='end';
            end
            else if (s='else') then
            begin
                pcurrec^.expect[1]:='begin';
                pcurrec^.expect[2]:=';';
            end
            else if ((s='to') or (s='downto')) then
            begin
                pcurrec^.expect[1]:='do';
            end
            else if (s='do') then
            begin
                pcurrec^.expect[1]:='end';
                pcurrec^.expect[2]:=';';
            end
            else if (s='then') then
            begin
                pcurrec^.expect[1]:='begin';
                pcurrec^.expect[2]:='else';
                pcurrec^.expect[3]:=';';
            end
            else if (s='while') then
            begin
                pcurrec^.expect[1]:='do';
            end
            else if (s='for') then
            begin
                pcurrec^.expect[1]:='to';
                pcurrec^.expect[2]:='downto';
            end
            else if (s='if') then
            begin
                pcurrec^.expect[1]:='then';
            end;
            t1:=stack_get.n;
            writeln('// t1:',t1);
            if (s='then') then
            begin
                writeln('n_',n_n+1,'[shape=diamond,label="',trim(substring(stack_get().l,lexpos-length('then '))),'"];');
                writeln('n_',n_n,'->n_',(n_n+1),';');
                writeln('n_',n_n+1,'->n_',(n_n+2),';');
                writeln('n_',n_n+1,'->n_',(n_n+3),';');
                writeln('{n_',n_n+1,';n_',(n_n+2),'; rank=same;}');
                writeln('n_',n_n+2,'[shape=point];');
                writeln('n_',n_n+3,'[shape=point];');
                suppstack_push(n_n+3);
                accum:='';
                n_n:=n_n+3;
            end
            else if (s='else') then
            begin
                suppstack2_push(n_n);
                if (suppstack_get()<high(integer)) then
                writeln('n_',suppstack_pop()-1,'->n_',n_n+1,';');
            end
            else if ((s='do') and ((stack_get.n='to') or (stack_get.n='downto'))) then
            begin
                writeln('n_',n_n,'->n_',(n_n+1),';');
                writeln('n_',n_n+1,'[shape=trapezium,label="',trim(substring(stack_pop().l,lexpos)),'"];');
                accum:='';
                n_n:=n_n+1;
            end
            else if ((s='do') and (stack_get.n='while')) then
            begin
                writeln('n_',n_n,'->n_',(n_n+1),';');
                writeln('n_',n_n+1,'[shape=trapezium,label="',trim(substring(stack_pop().l,lexpos)),'"];');
                accum:='';
                n_n:=n_n+1;
            end
            else if (s='repeat') then
            begin
                writeln('n_',n_n,'->n_',(n_n+1),';');
                writeln('n_',n_n+1,'[shape=trapezium,label=""];');
                accum:='';
                n_n:=n_n+1;

            end;
            stack_push(pcurrec^);
        end
        else
        begin
            accum:=accum+s;
        end;
    end;
    writeln('n_',n_n+1,'[label=end];');
    writeln('n_',n_n,'->n_',n_n+1,';');
    writeln('}');
    close(output);
    exec('graphviz/bin/dot.exe',' -Tpng output.txt -o flowchart.png');
    {exec('graphviz/bin/dot.exe',' -Tsvg output.txt -o flowchart.svg');}
end.
