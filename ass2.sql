-- COMP3311 20T3 Assignment 2
-- writen by XiaoHu z5223731
-- Q1: students who've studied many courses

create or replace view fun(id, count)
as
   select course_enrolments.student, count(*)
   from course_enrolments join people on people.id = course_enrolments.student
   group by course_enrolments.student
;

create or replace view Q1(unswid, name)
as
   select people.unswid, people.name
   from people join fun on fun.id = people.id
   where fun.count > 65
;

-- Q2: numbers of students, staff and both

create or replace view nstudents(num)
as
   select count(*)
   from students left join staff on students.id = staff.id
   where staff.id is null
;

create or replace view nstaff(num)
as
   select count(*)
   from staff left join students on staff.id = students.id
   where students.id is null
;

create or replace view nboth(num)
as
   select count(*)
   from students left join staff on students.id = staff.id
   where students.id is not null and staff.id is not null
;

create or replace view Q2(nstudents,nstaff,nboth)
as
   select nstudents.num as nstudents, nstaff.num as nstaff, nboth.num as nboth
   from nstudents, nstaff, nboth
;

-- Q3: prolific Course Convenor(s)

create or replace function getid(text) returns integer
as
$$
   select Staff_roles.id from Staff_roles where Staff_roles.name = $1
$$ language sql
;

create or replace view cct(name,ncourses)
as
   select people.name as name, count(*) as ncourses
   from people, Course_staff
   where people.id = Course_staff.staff and Course_staff.role = getid('Course Convenor')
   group by people.id
;

create or replace view Q3(name,ncourses)
as
   select name, ncourses from cct
   where ncourses = (select max(ncourses) from cct)
;

-- Q4: Comp Sci students in 05s2 and 17s1


create or replace view Q4a(id,name)
as
   select people.unswid as id, people.name
   from Students, people, Program_enrolments, Terms, Programs
   where Students.id = people.id
      and Students.id = student
      and program = Programs.id
      and term = Terms.id
      and Terms.longname = 'Semester 2 2005'
      and Programs.code = '3978'
      and Programs.name = 'Computer Science'
   order by id
;

create or replace view Q4b(id,name)
as
   select people.unswid as id, people.name
   from Students, people, Program_enrolments, Terms, Programs
   where Students.id = people.id
      and Students.id = student
      and program = Programs.id
      and term = Terms.id
      and Terms.longname = 'Semester 1 2017'
      and Programs.code = '3778'
      and Programs.name = 'Computer Science'
   order by id
;

-- Q5: most "committee"d faculty

create or replace view facultyid(id, fid)
as
   select id, facultyOf(id) as fid from OrgUnits
   where facultyOf(id) is not null
;

create or replace view faculty_commitees(id, count)
as
   select facultyid.fid as id, count(*)from facultyid 
   join OrgUnit_groups on OrgUnit_groups.owner = facultyid.id
   join OrgUnits on OrgUnits.id = OrgUnit_groups.member
   join OrgUnit_types on OrgUnit_types.id = OrgUnits.utype
   where OrgUnit_types.name = 'Committee'
   group by facultyid.fid
;

create or replace view Q5(name)
as
   select OrgUnits.name from OrgUnits
   join faculty_commitees on faculty_commitees.id = OrgUnits.id
   where faculty_commitees.count = (select max(count) from faculty_commitees)
;

-- Q6: nameOf function

create or replace function
   Q6(id integer) returns text
as $$
   select People.name from People
   where People.unswid = $1
   or People.id = $1
$$ language sql;

-- Q7: offerings of a subject

create or replace function
   Q7(subject text)
     returns table (subject text, term text, convenor text)
as $$
   select cast(Subjects.code as text) as subject, termName(Terms.id) as term, People.name as convenor
   from Subjects, Terms, People, Courses, Course_staff, Staff_roles
   where Subjects.code = $1
      and Subjects.id = Courses.subject
      and Courses.term = Terms.id
      and Course_staff.course = Courses.id
      and People.id = Course_staff.staff
      and Staff_roles.id = Course_staff.role
      and Staff_roles.name = 'Course Convenor'

$$ language sql;

-- Q8: transcript

create or replace function
   Q8(zid integer) returns setof TranscriptRecord
as $$
declare
   record TranscriptRecord;
   total_wam float := 0;
   total_uoc integer := 0;
   uoc integer := 0;
begin
   for record in
      select Subjects.code, termName(Terms.id) as term, Programs.code as prog, substr(Subjects.name, 1, 20) as name, Course_enrolments.mark, Course_enrolments.grade, Subjects.uoc
      from Subjects, Terms, Programs, Course_enrolments, Students, program_enrolments, Courses, People
      where People.unswid = $1
         and Students.id = People.id
         and program_enrolments.student = Students.id
         and Programs.id = program_enrolments.program
         and Course_enrolments.student = Students.id
         and Course_enrolments.course = Courses.id
         and Courses.subject = Subjects.id
         and Courses.term = Terms.id
         and Terms.id = program_enrolments.term
      order by termName(Terms.id), Subjects.code
   loop
      if record.mark is not null
      then
         total_wam := total_wam + (record.mark * record.uoc);
         total_uoc := total_uoc + record.uoc;
      end if;
      if record.grade in ('SY', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 'B', 'C')
      then
         uoc := uoc + record.uoc;
      elsif record.grade in ('XE', 'T', 'PE', 'RC', 'RS', 'SY')
      then
         total_wam := round(total_wam);
         uoc := uoc + record.uoc;
      else
         record.uoc = null;
      end if;
      return next record;
   end loop;

   record = (null, null, null, 'Overall WAM/UOC', round(total_wam/total_uoc), null, uoc);
   return next record;
end;
$$ language plpgsql;

--Q9: members of academic object group

create or replace function
   Q9(gid integer) returns setof AcObjRecord
as $$
declare
   obj AcObjRecord;
   gt text;
   gd text;
   co text;
   tmp text;
   tmpco text;
   par integer;
begin
   select gtype into gt from Acad_object_groups where id = $1;
   select gdefBy into gd from Acad_object_groups where id = $1;
   if gd = 'enumerated'
   then
      if gt = 'subject'
      then
         for co in
            select code from Subjects where id in (select subject from subject_group_members where ao_group = $1)
         loop
            obj = (gt, co);
            return next obj;
         end loop;
         for par in
            select id from acad_object_groups where parent = $1
         loop
            for co in 
               select code from Subjects where id in (select subject from subject_group_members where ao_group = par)
            loop
               obj = (gt, co);
               return next obj;
            end loop;
         end loop;
      elsif gt = 'program'
      then
         for co in
            select code from Programs where id in (select program from program_group_members where ao_group = $1)
         loop
            obj = (gt, co);
            return next obj;
         end loop;
         for par in
            select id from acad_object_groups where parent = $1
         loop
            for co in 
               select code from Programs where id in (select program from program_group_members where ao_group = par)
            loop
               obj = (gt, co);
               return next obj;
            end loop;
         end loop;
      else
         for co in
            select code from Streams where id in (select stream from stream_group_members where ao_group = $1)
         loop
            obj = (gt, co);
            return next obj;
         end loop;
         for par in
            select id from acad_object_groups where parent = $1
         loop
            for co in 
               select code from Streams where id in (select stream from stream_group_members where ao_group = par)
            loop
               obj = (gt, co);
               return next obj;
            end loop;
         end loop;
      end if;
-- pattern-based
   else
      for co in
         select regexp_split_to_table(definition, ',') from acad_object_groups where id = $1
      loop
         if (position(E'\\[' in co) <> 0)
         then
            tmpco = regexp_matches(co, '(A-Z)+\[', 'g');
            obj = (gt, 'here');
            return next obj;
            for tmp in
               select regexp_matches(co, '\[(0-9)+\]', 'g')
            loop
               obj = (gt, 'here');
               return next obj;
            end loop;
         end if;
         obj = (gt, co);
         return next obj;
      end loop;
   end if;

end;
$$ language plpgsql;

-- Q10: follow-on courses

--create or replace function
--   Q10(code text) returns setof text
--as $$



--$$ language plpgsql;