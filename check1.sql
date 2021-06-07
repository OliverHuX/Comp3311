-- COMP3311 20T3 Assignment 2
--
-- check.sql ... checking functions
--
-- Written by: John Shepherd, September 2012
-- Updated by: John Shepherd, October 2020
--

--
-- Helper functions
--

create or replace function
	ass2_table_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='r';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	ass2_view_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='v';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	ass2_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;

-- ass2_check_result:
-- * determines appropriate message, based on count of
--   excess and missing tuples in user output vs expected output

create or replace function
	ass2_check_result(nexcess integer, nmissing integer) returns text
as $$
begin
	if (nexcess = 0 and nmissing = 0) then
		return 'correct';
	elsif (nexcess > 0 and nmissing = 0) then
		return 'too many result tuples';
	elsif (nexcess = 0 and nmissing > 0) then
		return 'missing result tuples';
	elsif (nexcess > 0 and nmissing > 0) then
		return 'incorrect result tuples';
	end if;
end;
$$ language plpgsql;

-- ass2_check:
-- * compares output of user view/function against expected output
-- * returns string (text message) containing analysis of results

create or replace function
	ass2_check(_type text, _name text, _res text, _query text) returns text
as $$
declare
	nexcess integer;
	nmissing integer;
	excessQ text;
	missingQ text;
begin
	if (_type = 'view' and not ass2_view_exists(_name)) then
		return 'No '||_name||' view; did it load correctly?';
	elsif (_type = 'function' and not ass2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (not ass2_table_exists(_res)) then
		return _res||': No expected results!';
	else
		excessQ := 'select count(*) '||
			   'from (('||_query||') except '||
			   '(select * from '||_res||')) as X';
		-- raise notice 'Q: %',excessQ;
		execute excessQ into nexcess;
		missingQ := 'select count(*) '||
			    'from ((select * from '||_res||') '||
			    'except ('||_query||')) as X';
		-- raise notice 'Q: %',missingQ;
		execute missingQ into nmissing;
		return ass2_check_result(nexcess,nmissing);
	end if;
	return '???';
end;
$$ language plpgsql;

-- ass2_rescheck:
-- * compares output of user function against expected result
-- * returns string (text message) containing analysis of results

create or replace function
	ass2_rescheck(_type text, _name text, _res text, _query text) returns text
as $$
declare
	_sql text;
	_chk boolean;
begin
	if (_type = 'function' and not ass2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (_res is null) then
		_sql := 'select ('||_query||') is null';
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	else
		_sql := 'select ('||_query||') = '||quote_literal(_res);
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	end if;
	if (_chk) then
		return 'correct';
	else
		return 'incorrect result';
	end if;
end;
$$ language plpgsql;

-- check_all:
-- * run all of the checks and return a table of results

drop type if exists TestingResult cascade;
create type TestingResult as (test text, result text);

create or replace function
	check_all() returns setof TestingResult
as $$
declare
	i int;
	testQ text;
	result text;
	out TestingResult;
	tests text[] := array[
				'q1', 'q2', 'q3', 'q4a', 'q4b', 'q5', 
				'q6a', 'q6b', 'q6c', 'q7a', 'q7b', 'q7c',
				'q8a', 'q8b', 'q8c', 'q9a', 'q9b', 'q9c',
				'q10a','q10b','q10c'
				];
begin
	for i in array_lower(tests,1) .. array_upper(tests,1)
	loop
		testQ := 'select check_'||tests[i]||'()';
		execute testQ into result;
		out := (tests[i],result);
		return next out;
	end loop;
	return;
end;
$$ language plpgsql;


--
-- Test Cases
--

-- Q1 --

create or replace function check_q1() returns text
as $chk$
select ass2_check('view','q1','q1_expected',
                   $$select * from q1$$)
$chk$ language sql;

drop table if exists q1_expected;
create table q1_expected (
    unswid integer,
    name longname
);

COPY q1_expected (unswid, name) FROM stdin;
3012907	Jordan Sayed
3101627	Yiu Man
3137719	Vu-Minh Samarasekera
3139456	Minna Henry-May
3158621	Sanam Sam
3163349	Kerry Plant
3193072	Ivan Tsitsiani
3195354	Marliana Sondhi
\.

-- Q2 --

create or replace function check_q2() returns text
as $chk$
select ass2_check('view','q2','q2_expected',
                   $$select * from q2$$)
$chk$ language sql;

drop table if exists q2_expected;
create table q2_expected (
    nstudents bigint,
    nstaff bigint,
    nboth bigint
);

COPY q2_expected (nstudents, nstaff, nboth) FROM stdin;
31361	24405	0
\.


-- Q3 --

create or replace function check_q3() returns text
as $chk$
select ass2_check('view','q3','q3_expected',
                   $$select * from q3$$)
$chk$ language sql;

drop table if exists q3_expected;
create table q3_expected (
    name longname,
    ncourses bigint
);

COPY q3_expected (name, ncourses) FROM stdin;
Susan Hagon	248
\.


-- Q4 --

create or replace function check_q4a() returns text
as $chk$
select ass2_check('view','q4a','q4a_expected',
                   $$select * from q4a$$)
$chk$ language sql;

drop table if exists q4a_expected;
create table q4a_expected (
    id integer,
	name text
);

COPY q4a_expected (id,name) FROM stdin;
3040773	Tonny Andrewartha
3124015	Shudo Suzuki Cheung
3124711	Irene Van Saane
3126551	Adrian Andary
3128290	Nathan Asplet
3131729	Yilu Zhang Ying
3144015	Ayako Kao
3159387	Demyan Holczer
3172526	Janet Sutcliffe
3173265	Michael Maclachlan
3183655	Rachael Dunkley
3192680	Luke De Luca
\.

create or replace function check_q4b() returns text
as $chk$
select ass2_check('view','q4b','q4b_expected',
                   $$select * from q4b$$)
$chk$ language sql;

drop table if exists q4b_expected;
create table q4b_expected (
    id integer,
	name text
);

COPY q4b_expected (id) FROM stdin;
\.


-- Q5 --

create or replace function check_q5() returns text
as $chk$
select ass2_check('view','q5','q5_expected',
                   $$select * from q5$$)
$chk$ language sql;

drop table if exists q5_expected;
create table q5_expected (
    name text
);

COPY q5_expected (name) FROM stdin;
Faculty of Engineering
\.


-- Q6 --

create or replace function check_q6a() returns text
as $chk$
select ass2_check('function','q6','q6a_expected',
                   $$select q6(3012907)$$)
$chk$ language sql;

drop table if exists q6a_expected;
create table q6a_expected (
    q6 text
);

COPY q6a_expected (q6) FROM stdin;
Jordan Sayed
\.

create or replace function check_q6b() returns text
as $chk$
select ass2_check('function','q6','q6b_expected',
                   $$select q6(1076226)$$)
$chk$ language sql;

drop table if exists q6b_expected;
create table q6b_expected (
    q6 text
);

COPY q6b_expected (q6) FROM stdin;
Jordan Sayed
\.

create or replace function check_q6c() returns text
as $chk$
select ass2_check('function','q6','q6c_expected',
                   $$select q6(12345)$$)
$chk$ language sql;

drop table if exists q6c_expected;
create table q6c_expected (
    q6 text
);

COPY q6c_expected (q6) FROM stdin;
\N
\.


-- Q7 --

create or replace function check_q7a() returns text
as $chk$
select ass2_check('function','q7','q7a_expected',
                   $$select * from q7('COMP1711')$$)
$chk$ language sql;

drop table if exists q7a_expected;
create table q7a_expected (
    subject text,
    term text,
    convenor text
);

COPY q7a_expected (subject, term, convenor) FROM stdin;
COMP1711	03s1	Richard Buckland
\.

create or replace function check_q7b() returns text
as $chk$
select ass2_check('function','q7','q7b_expected',
                   $$select * from q7('COMP3311')$$)
$chk$ language sql;

drop table if exists q7b_expected;
create table q7b_expected (
    subject text,
    term text,
    convenor text
);

COPY q7b_expected (subject, term, convenor) FROM stdin;
COMP3311	03s1	John Shepherd
COMP3311	03s2	Kwok Wong
COMP3311	06s1	Wei Wang
COMP3311	06s2	John Shepherd
COMP3311	07a1	John Shepherd
COMP3311	07a2	Wei Wang
COMP3311	08s1	John Shepherd
COMP3311	09s1	John Shepherd
COMP3311	10s1	Xuemin Lin
COMP3311	11s1	John Shepherd
COMP3311	12s1	John Shepherd
COMP3311	13s2	John Shepherd
\.

create or replace function check_q7c() returns text
as $chk$
select ass2_check('function','q7','q7c_expected',
                   $$select * from q7('MATH1131')$$)
$chk$ language sql;

drop table if exists q7c_expected;
create table q7c_expected (
    subject text,
    term text,
    convenor text
);

COPY q7c_expected (subject, term, convenor) FROM stdin;
MATH1131	07a1	Michael Hirschhorn
MATH1131	07a2	David Crocker
MATH1131	08s1	Peter Blennerhassett
MATH1131	08s2	David Crocker
MATH1131	09s1	Peter Blennerhassett
MATH1131	09s2	David Angell
MATH1131	10s1	Peter Blennerhassett
MATH1131	10s2	Milan Pahor
MATH1131	11s1	Gary Froyland
MATH1131	11s2	Dennis Trenerry
MATH1131	12s1	Thomas Britz
MATH1131	12s2	Thomas Britz
MATH1131	13s1	John Murray
MATH1131	13s2	Milan Pahor
\.


-- Q8 --

create or replace function check_q8a() returns text
as $chk$
select ass2_check('function','q8','q8a_expected',
                   $$select * from q8(3489313)$$)
$chk$ language sql;

drop table if exists q8a_expected;
create table q8a_expected (
    code character(8),
    term character(4),
    prog character(4),
    name text,
    mark integer,
    grade character(2),
    uoc integer
);

COPY q8a_expected (code, term, prog, name, mark, grade, uoc) FROM stdin;
ARTS1750	12s1	3432	Intro to Development	78	DN	6
EDST1101	12s1	3432	Educational Psycholo	80	DN	6
PSYC1001	12s1	3432	Psychology 1A	84	DN	6
PSYC1021	12s1	3432	Intro to Psych Appli	84	DN	6
ARTS1062	12s2	3432	Hollywood Film	75	DN	6
ARTS1871	12s2	3432	Relationship	64	PS	6
CRIM1011	12s2	3432	Intro to Criminal Ju	63	PS	6
PSYC1011	12s2	3432	Psychology 1B	72	CR	6
ARTS2284	13x1	3432	Europe in the Middle	51	PS	6
GENM0518	13x1	3432	Health & Power in In	97	HD	6
\N	\N	\N	Overall WAM/UOC	75	\N	60
\.

create or replace function check_q8b() returns text
as $chk$
select ass2_check('function','q8','q8b_expected',
                   $$select * from q8(1053721)$$)
$chk$ language sql;

drop table if exists q8b_expected;
create table q8b_expected (
    code character(8),
    term character(4),
    prog character(4),
    name text,
    mark integer,
    grade character(2),
    uoc integer
);

COPY q8b_expected (code, term, prog, name, mark, grade, uoc) FROM stdin;
SAHT1102	07a2	4800	Beyond Modernities	82	DN	6
SART1501	07a2	4800	Painting	75	DN	6
SART1601	07a2	4800	Sculpture	85	HD	6
SOMA1521	07a2	4800	Introduction to Anal	73	CR	6
SAHT1101	08s1	4800	Narratives of Modern	\N	T	6
SART1502	08s1	4800	Drawing	\N	T	6
SOMA2521	08s1	4800	Intro to Studio Ligh	87	HD	6
SOMA3858	08s2	4800	Advanced Studio Ligh	77	DN	6
SART2842	09s1	4800	Metal Casting	92	HD	6
SOMA2321	09s1	4800	Photomedia 2A	74	CR	6
SOMA2341	09s1	4800	Photomedia 2B	87	HD	6
SAHT3211	09s2	4800	Art Since 1990	69	CR	6
SOMA2331	09s2	4800	Photomedia 3A	83	DN	6
SOMA2351	09s2	4800	Photomedia 3B	89	HD	6
GENL1062	10x1	4800	Understanding Human 	71	CR	6
SOMA3341	10s1	4800	Photomedia 4A	78	DN	6
SOMA3616	10s1	4800	Professional Practic	81	DN	6
SAHT2668	10s2	4800	Photography's Histor	63	PS	6
SOMA3351	10s2	4800	Photomedia 5A	71	CR	6
SOMA3361	11s1	4800	Photomedia 4B	78	DN	6
SOMA3371	11s2	4800	Photomedia 5B	80	DN	6
\N	\N	\N	Overall WAM/UOC	79	\N	126
\.

create or replace function check_q8c() returns text
as $chk$
select ass2_check('function','q8','q8c_expected',
                   $$select * from q8(3202320)$$)
$chk$ language sql;

drop table if exists q8c_expected;
create table q8c_expected (
    code character(8),
    term character(4),
    prog character(4),
    name text,
    mark integer,
    grade character(2),
    uoc integer
);

COPY q8c_expected (code, term, prog, name, mark, grade, uoc) FROM stdin;
COMP1917	09s1	3645	Computing 1	83	DN	6
ENGG1000	09s1	3645	Engineering Design	65	CR	6
MATH1131	09s1	3645	Mathematics 1A	46	PC	6
PHYS1121	09s1	3645	Physics 1A	31	FL	\N
COMP1927	09s2	3645	Computing 2	67	CR	6
ELEC1111	09s2	3645	Elec & Telecomm Eng	51	PS	6
MATH1231	09s2	3645	Mathematics 1B	52	PS	6
PHYS1121	09s2	3645	Physics 1A	55	PS	6
PHYS1221	10x1	3645	Physics 1B	37	FL	\N
COMP2121	10s1	3645	Microprocessors & In	55	PS	6
COMP2911	10s1	3645	Eng. Design in Compu	70	CR	6
ELEC2134	10s1	3645	Circuits and Signals	25	FL	\N
MATH2069	10s1	3645	Mathematics 2A	42	FL	\N
COMP3222	10s2	3645	Digital Circuits and	50	PS	6
ELEC2134	10s2	3645	Circuits and Signals	51	PS	6
MATH2099	10s2	3645	Mathematics 2B	35	FL	\N
PHYS1221	10s2	3645	Physics 1B	28	FL	\N
GENC3003	11x1	3645	Personal Financial P	62	PS	3
PHYS1221	11x1	3645	Physics 1B	40	FL	\N
COMP3211	11s1	3645	Computer Architectur	61	PS	6
COMP3231	11s1	3645	Operating Systems	55	PS	6
COMP3311	11s1	3645	Database Systems	59	PS	6
MATH2069	11s1	3645	Mathematics 2A	45	FL	\N
COMP3171	11s2	3645	Object-Oriented Prog	65	CR	6
COMP3331	11s2	3645	Computer Networks&Ap	67	CR	6
COMP3601	11s2	3645	Design Project A	76	DN	6
GENS4010	11s2	3645	Science and Religion	60	PS	6
MATH2099	11s2	3645	Mathematics 2B	59	PS	6
PHYS1221	12x1	3645	Physics 1B	33	FL	\N
TELE3113	12x1	3645	Analogue and Digital	42	FL	\N
COMP4001	12s1	3645	Object-Oriented Soft	25	FL	\N
COMP9321	12s1	3645	Web Applications Eng	74	CR	6
COMP9333	12s1	3645	Advanced Computer Ne	89	HD	6
MATH2069	12s1	3645	Mathematics 2A	32	FL	\N
COMP4920	12s2	3645	Professional Issues 	41	FL	\N
COMP9322	12s2	3645	Service-Oriented Arc	56	PS	6
COMP9323	12s2	3645	e-Enterprise Project	57	PS	6
\N	\N	\N	Overall WAM/UOC	52	\N	141
\.


-- Q9 --

create or replace function check_q9a() returns text
as $chk$
select ass2_check('function','q9','q9a_expected',
                   $$select * from q9(1530)$$)
$chk$ language sql;

drop table if exists q9a_expected;
create table q9a_expected (
    objtype text,
    objcode text
);

COPY q9a_expected (objtype, objcode) FROM stdin;
stream	BINFA1
\.

create or replace function check_q9b() returns text
as $chk$
select ass2_check('function','q9','q9b_expected',
                   $$select * from q9(1144)$$)
$chk$ language sql;

drop table if exists q9b_expected;
create table q9b_expected (
    objtype text,
    objcode text
);

COPY q9b_expected (objtype, objcode) FROM stdin;
subject	CHEM1011
subject	CHEM1031
subject	COMP1911
subject	ENGG1000
subject	ENGG1811
subject	MATH1131
subject	MATH1141
subject	MATH1231
subject	MATH1241
subject	MATS1101
subject	PHYS1121
subject	PHYS1131
\.

create or replace function check_q9c() returns text
as $chk$
select ass2_check('function','q9','q9c_expected',
                   $$select * from q9(1117)$$)
$chk$ language sql;

drop table if exists q9c_expected;
create table q9c_expected (
    objtype text,
    objcode text
);

COPY q9c_expected (objtype, objcode) FROM stdin;
subject	BABS1201
subject	BIOM1010
subject	BIOS1301
subject	CEIC1000
subject	CEIC1001
subject	CHEM1011
subject	CHEM1021
subject	CHEM1031
subject	CHEM1041
subject	COMP1921
subject	CVEN1300
subject	CVEN1701
subject	ELEC1111
subject	GEOS1111
subject	GEOS3321
subject	GMAT1110
subject	GMAT1400
subject	MATH1081
subject	MATS1101
subject	MINE1010
subject	MINE1300
subject	MMAN1130
subject	MMAN1300
subject	PHYS1231
subject	PSYC1001
subject	PTRL1010
subject	SOLA1070
\.


-- Q10 --

create or replace function check_q10a() returns text
as $chk$
select ass2_check('function','q10','q10a_expected',
                   $$select * from q10('COMP9321')$$)
$chk$ language sql;

drop table if exists q10a_expected;
create table q10a_expected (
    q10 text
);

COPY q10a_expected (q10) FROM stdin;
COMP9322
\.

create or replace function check_q10b() returns text
as $chk$
select ass2_check('function','q10','q10b_expected',
                   $$select * from q10('COMP3311')$$)
$chk$ language sql;

drop table if exists q10b_expected;
create table q10b_expected (
    q10 text
);

COPY q10b_expected (q10) FROM stdin;
COMP4314
COMP9315
COMP9318
COMP9321
\.

create or replace function check_q10c() returns text
as $chk$
select ass2_check('function','q10','q10c_expected',
                   $$select * from q10('MMAN2600')$$)
$chk$ language sql;

drop table if exists q10c_expected;
create table q10c_expected (
    q10 text
);

COPY q10c_expected (q10) FROM stdin;
AERO3630
MECH3204
MECH3540
MECH3601
MECH3602
MECH3610
MECH9620
MECH9720
MECH9751
MMAN3210
NAVL3610
\.

