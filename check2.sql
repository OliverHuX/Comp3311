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
				'q6a', 'q6b', 'q7a', 'q7b', 'q7c',
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
31361	24407	0
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
David Lovell	140
Duncan Chalmers	140
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

COPY q4b_expected (id,name) FROM stdin;
3267637	Manling Wang Jing
3247384	Warren Sadaka
3168864	Kejiao Xing
6952177	Amelia Ongel
3121598	Gregory Minion
3266162	Monica-Nicole Mahfoud
3091426	Nasir Fortuna
3031941	Sunny Mar
3262889	Tara Eva
3200416	Praveen Jagadesan
3312220	Craig Stromer
3276884	Jaimi Blume-Poulton
3254840	Gera Marzotto
3221869	Christopher Haisell
3290500	Tracey Schreter
3304648	Byron Bergseng
3269018	Zhi-Cheng Xiao
3284796	Crystal Zhang Lingqing
3371806	Timothy Harb
3223173	Robin Kalinowski
3197686	Venetia Soo Kee
3216260	Alexandra Sarian
3223684	Shaun De Rooy
3152489	Moses Mamat
3224604	Hana Berntsen
3213623	Harumi Wilson
3279041	Ronak Pangasa
3185124	Muhammad Fung
3207679	Jennifer Dix
3237106	Oliver Oliver
3270124	Florian Kruetzen
3267046	Michael Gronlund
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
Faculty of Law
\.


-- Q6 --

create or replace function check_q6a() returns text
as $chk$
select ass2_check('function','q6','q6a_expected',
                   $$select q6(5011111)$$)
$chk$ language sql;

drop table if exists q6a_expected;
create table q6a_expected (
    q6 text
);

COPY q6a_expected (q6) FROM stdin;
Ian Jacobs
\.

create or replace function check_q6b() returns text
as $chk$
select ass2_check('function','q6','q6b_expected',
                   $$select q6(3333456)$$)
$chk$ language sql;

drop table if exists q6b_expected;
create table q6b_expected (
    q6 text
);

COPY q6b_expected (q6) FROM stdin;
Marc Chee
\.


-- Q7 --

create or replace function check_q7a() returns text
as $chk$
select ass2_check('function','q7','q7a_expected',
                   $$select * from q7('COMP1511')$$)
$chk$ language sql;

drop table if exists q7a_expected;
create table q7a_expected (
    subject text,
    term text,
    convenor text
);

COPY q7a_expected (subject, term, convenor) FROM stdin;
COMP1511	17s1	Andrew Taylor
COMP1511	17s2	Angela Finlayson
COMP1511	18s1	Andrew Taylor
COMP1511	18s2	Ashesh Mahidadia
COMP1511	19T1	Marc Chee
COMP1511	19T2	Marc Chee
COMP1511	19T3	Marc Chee
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
COMP3311	03s2	Raymond Wong
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
COMP3311	15s1	Xuemin Lin
COMP3311	16s1	Xuemin Lin
COMP3311	17s1	Xuemin Lin
COMP3311	18s1	Raymond Wong
COMP3311	19T1	Raymond Wong
COMP3311	19T3	John Shepherd
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
                   $$select * from q8(3011082)$$)
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
FNDN0301	15s2	6555	Computing Studies	\N	\N	\N
FNDN0501	15s2	6555	Academic English	\N	\N	\N
FNDN0603	15s2	6555	Mathematics - Scienc	\N	\N	\N
FNDN0702	15s2	6555	Chemistry	\N	\N	\N
FNDN0703	15s2	6555	Physics	\N	\N	\N
FNDN0301	16s1	6555	Computing Studies	\N	\N	\N
FNDN0501	16s1	6555	Academic English	\N	\N	\N
FNDN0603	16s1	6555	Mathematics - Scienc	\N	\N	\N
FNDN0702	16s1	6555	Chemistry	\N	\N	\N
FNDN0703	16s1	6555	Physics	\N	\N	\N
FNDN0301	16s2	6555	Computing Studies	\N	\N	\N
FNDN0501	16s2	6555	Academic English	\N	\N	\N
FNDN0603	16s2	6555	Mathematics - Scienc	\N	\N	\N
FNDN0702	16s2	6555	Chemistry	\N	\N	\N
FNDN0703	16s2	6555	Physics	\N	\N	\N
ENGG1811	17s1	3707	Computing for Engine	53	PS	6
MATH1131	17s1	3707	Mathematics 1A	56	PS	6
MATS1101	17s1	3707	Engineering Material	60	PS	6
PHYS1121	17s1	3707	Physics 1A	70	CR	6
CVEN1300	17s2	3707	Engineering Mechanic	50	PS	6
ENGG1000	17s2	3707	Engineering Design	59	PS	6
ENGG1400	17s2	3707	Eng Infrastructure S	59	PS	6
MATH1231	17s2	3707	Mathematics 1B	50	PS	6
CVEN2301	18s1	3707	Mechanics of Solids	64	PS	6
CVEN2401	18s1	3707	Sustainable Trans & 	54	PS	6
CVEN2501	18s1	3707	Principles of Water 	57	PS	6
MATH2019	18s1	3707	Engineering Mathemat	50	PS	6
CVEN2002	18s2	3707	Engineering Computat	64	PS	6
CVEN2101	18s2	3707	Engineering Construc	63	PS	6
CVEN2303	18s2	3707	Structural Analysis	0	NC	\N
CVEN3304	18s2	3707	Concrete Structures	52	PS	6
CVEN3202	19T1	3707	Soil Mechanics	39	FL	\N
CVEN3303	19T1	3707	Steel Structures	89	HD	6
CVEN3501	19T1	3707	Water Resources Engi	72	CR	6
CVEN3031	19T2	3707	Civil Engineering Pr	53	PS	6
CVEN3502	19T2	3707	Water & Wastewater E	53	PS	6
CVEN4402	19T2	3707	Transport Systems Pa	68	CR	6
CVEN3101	19T3	3707	Engineering Operatio	59	PS	6
CVEN3202	19T3	3707	Soil Mechanics	53	PS	6
CVEN4050	19T3	3707	Thesis A	68	CR	6
\N	\N	\N	Overall WAM/UOC	57	\N	138
\.

create or replace function check_q8b() returns text
as $chk$
select ass2_check('function','q8','q8b_expected',
                   $$select * from q8(3206530)$$)
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
ELEC2134	15s1	3707	Circuits and Signals	62	PS	6
MATH2069	15s1	3707	Mathematics 2A	63	PS	6
SOLA2051	15s1	3707	Project in PV and SE	\N	SY	6
SOLA2060	15s1	3707	Intro to Elec Device	73	CR	6
MATH2089	15s2	3707	Numerical Methods & 	58	PS	6
SOLA2052	15s2	3707	Project in PV and SE	76	DN	6
SOLA2053	15s2	3707	Sust. & Renew. En. T	67	CR	6
SOLA2540	15s2	3707	Applied PV	71	CR	6
PHYS1160	16x1	3707	Introduction to Astr	85	HD	6
PHYS1221	16x1	3707	Physics 1B	65	CR	6
MATH2019	16s1	3707	Engineering Mathemat	67	CR	6
SOLA3507	16s1	3707	Solar Cells	58	PS	6
SOLA4012	16s1	3707	Grid-Connect PV Syst	67	CR	6
SOLA5057	16s1	3707	Energy Efficiency	83	DN	6
GENC3004	16s2	3707	Personal Finance	73	CR	6
SOLA3010	16s2	3707	Low Energy Buildings	68	CR	6
SOLA3020	16s2	3707	PV Technology & Manu	52	PS	6
SOLA5054	16s2	3707	PV Stand-Alone Sys. 	79	DN	6
ELEC3115	17s1	3707	Electromagnetic Engi	56	PS	6
ELEC9714	17s1	3707	Electricity Industry	79	DN	6
SOLA4910	17s1	3707	Thesis Part A	\N	SY	6
ELEC4122	17s2	3707	Strategic Leadership	65	CR	6
SOLA4911	17s2	3707	Thesis Part B	90	HD	6
SOLA5051	17s2	3707	Life Cycle Assessmen	52	PS	6
\N	\N	\N	Overall WAM/UOC	69	\N	144
\.

create or replace function check_q8c() returns text
as $chk$
select ass2_check('function','q8','q8c_expected',
                   $$select * from q8(3284796)$$)
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
COMP1917	16s1	3772	Computing 1	68	CR	6
ENGG1000	16s1	3772	Engineering Design	87	HD	6
MATH1141	16s1	3772	Higher Mathematics 1	78	DN	6
PHYS1131	16s1	3772	Higher Physics 1A	61	PS	6
COMP1927	16s2	3772	Computing 2	62	PS	6
ELEC1111	16s2	3772	Elec & Telecomm Eng	67	CR	6
MATH1241	16s2	3772	Higher Mathematics 1	65	CR	6
PHYS1231	16s2	3772	Higher Physics 1B	77	DN	6
COMP2121	17s1	3778	Microprocessors & In	72	CR	6
COMP2911	17s1	3778	Eng. Design in Compu	57	PS	6
MATH1081	17s1	3778	Discrete Mathematics	83	DN	6
COMP2041	17s2	3778	Software Constructio	54	PS	6
COMP3421	17s2	3778	Computer Graphics	64	PS	6
MATH3411	17s2	3778	Information, Codes a	87	HD	6
COMP3121	18s1	3778	Algorithms & Program	69	CR	6
COMP3231	18s1	3778	Operating Systems	61	PS	6
COMP6841	18s1	3778	Extended Security En	53	PS	6
COMP1521	18s2	3778	Computer Systems Fun	78	DN	6
COMP1531	18s2	3778	Software Eng Fundame	63	PS	6
COMP4920	18s2	3778	Professional Issues 	37	FL	\N
PHYS1160	19T1	3778	Introduction to Astr	46	FL	\N
\N	\N	\N	Overall WAM/UOC	67	\N	114
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
                   $$select * from q9(1946)$$)
$chk$ language sql;

drop table if exists q9c_expected;
create table q9c_expected (
    objtype text,
    objcode text
);

COPY q9c_expected (objtype, objcode) FROM stdin;
subject	ZEIT4500
subject	ZEIT4501
subject	ZEIT4600
subject	ZEIT4601
subject	ZEIT4602
subject	ZEIT4603
subject	ZEIT4604
subject	ZEIT4605
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
COMP9313
COMP9315
COMP9318
COMP9321
COMP9323
\.

create or replace function check_q10c() returns text
as $chk$
select ass2_check('function','q10','q10c_expected',
                   $$select * from q10('COMP2521')$$)
$chk$ language sql;

drop table if exists q10c_expected;
create table q10c_expected (
    q10 text
);

COPY q10c_expected (q10) FROM stdin;
COMP2511
COMP2911
COMP3121
COMP3141
COMP3151
COMP3161
COMP3231
COMP3311
COMP3331
COMP3411
COMP3431
COMP3821
COMP3891
COMP3900
COMP4141
COMP6451
COMP6452
COMP6714
COMP6721
COMP6841
COMP9313
COMP9315
COMP9318
COMP9319
COMP9417
COMP9444
COMP9517
COMP9844
\.

