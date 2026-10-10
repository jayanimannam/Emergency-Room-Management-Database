-- Emergency Room Management Database: reporting views and stored procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set session SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'er_hospital_management';
use er_hospital_management;

-- -------------------
-- Views
-- -------------------

-- [1] room_wise_view()
-- -----------------------------------------------------------------------------
/* This view provides an overview of patient room assignments, including the patients’ 
first and last names, room numbers, managing department names, assigned doctors' first and 
last names (through appointments), and nurses' first and last names (through room). 
It displays key relationships between patients, their assigned medical staff, and 
the departments overseeing their care. Note that there will be a row for each combination 
of assigned doctor and assigned nurse.*/
-- -----------------------------------------------------------------------------
create or replace view room_wise_view as
select pe.firstName, pe.lastName, r.roomNumber, d.longName, doc.firstName as doctor_fname, doc.lastName as doctor_lname, np.firstName as nurse_fname, np.lastName as nurse_lname
from room r
join patient pa on pa.ssn = r.occupiedBy
join person pe on pa.ssn = pe.ssn
join department d on r.managingDept = d.deptId
join room_assignment ra on r.roomNumber = ra.roomNumber
join nurse n on n.ssn = ra.nurseId
join person np on np.ssn = n.ssn
left join appt_assignment aa on pa.ssn = aa.patientId
left join doctor dr on dr.ssn = aa.doctorId
left join person doc on doc.ssn = dr.ssn
;

-- [2] symptoms_overview_view()
-- -----------------------------------------------------------------------------
/* This view provides a comprehensive overview of patient appointments
along with recorded symptoms. Each row displays the patient’s SSN, their full name 
, the appointment time, appointment date, 
and a list of symptoms recorded during the appointment with each symptom separated by a 
comma and a space . */
-- -----------------------------------------------------------------------------
create or replace view symptoms_overview_view as
select 
    pa.ssn, concat(pe.firstName, pe.lastName) as fullName, appt.apptDate, appt.apptTime, group_concat(s.symptomType order by s.symptomType separator ',') as symptoms
from appointment appt
join patient pa on pa.ssn = appt.patientId
join person pe on pe.ssn = pa.ssn
join symptom s on s.patientId = appt.patientId
   and s.apptDate  = appt.apptDate
   and s.apptTime  = appt.apptTime
group by 
    pa.ssn,
    pe.firstName,
    pe.lastName,
    appt.apptDate,
    appt.apptTime
;

-- [3] medical_staff_view()
-- -----------------------------------------------------------------------------
/* This view displays information about medical staff. For every nurse and doctor, it displays
their ssn, their "staffType" being either "nurse" or "doctor", their "licenseInfo" being either
their licenseNumber or regExpiration, their "jobInfo" being either their shiftType or 
experience, a list of all departments they work in in alphabetical order separated by a
comma and a space , and their "numAssignments" 
being either the number of rooms they're assigned to or the number of appointments they're assigned to. */
-- -----------------------------------------------------------------------------
create or replace view medical_staff_view as

SELECT n.ssn AS ssn, 'nurse' AS staffType, n.regExpiration AS licenseInfo, n.shiftType AS jobInfo,
    COALESCE( GROUP_CONCAT(DISTINCT d.longName ORDER BY d.longName SEPARATOR ', '), '') AS departments,                    
    (SELECT COUNT(*) FROM room_assignment ra WHERE ra.nurseId = n.ssn ) AS numAssignments  
FROM nurse n
LEFT JOIN works_in w ON n.ssn = w.staffSsn
LEFT JOIN department d ON d.deptId = w.deptId
GROUP BY n.ssn                              

UNION

SELECT doc.ssn AS ssn, 'doctor' AS staffType, doc.licenseNumber AS licenseInfo, doc.experience AS jobInfo,
    COALESCE(GROUP_CONCAT(DISTINCT d.longName ORDER BY d.longName SEPARATOR ', '), '') AS departments,                   
    ( SELECT COUNT(*) FROM appt_assignment aa
      WHERE aa.doctorId = doc.ssn ) AS numAssignments 
FROM doctor doc
LEFT JOIN works_in w ON doc.ssn = w.staffSsn
LEFT JOIN department d ON d.deptId = w.deptId
GROUP BY doc.ssn; 


-- [4] department_view()
-- -----------------------------------------------------------------------------
/* This view displays information about every department in the hospital. The information
displayed should be the department's long name, number of total staff members, the number of 
doctors in the department, and the number of nurses in the department. If a department does not 
have any doctors/nurses/staff members, ensure the output for those columns is zero, not null */
-- -----------------------------------------------------------------------------
create or replace view department_view as
select d.longName, count(*) as num_staff, count(doc.ssn) as doc_num, count(n.ssn) as n_num
from works_in w join department d on w.deptId = d.deptId
left join doctor doc on doc.ssn = w.staffSsn
left join nurse n on n.ssn = w.staffSsn
group by w.deptId
;

-- [5] outstanding_charges_view()
-- -----------------------------------------------------------------------------
/* This view displays the outstanding charges for the patients in the hospital. 
“Outstanding charges” is the sum of appointment costs and order costs. It also 
displays a patient’s first name, last name, SSN, funds, number of appointments, 
and number of orders. Ensure there are no null values if there are no charges, 
appointments, orders for a patient .  */
-- -----------------------------------------------------------------------------
create or replace view outstanding_charges_view as
select pe.firstName, pe.lastName, pe.ssn, pa.funds, IFNULL(appt_cost , 0) + IFNULL(order_cost, 0) as 'Outstanding charges', IFNULL(appt_table.num_appts,0) as num_appts, IFNULL(order_table.num_orders,0) as num_orders
from person pe join patient pa on pe.ssn = pa.ssn
left join ( select patientId, sum(cost) as appt_cost, count(*) as num_appts from appointment group by patientId) as appt_table
on pa.ssn = appt_table.patientId
left join ( select patientId, sum(cost) as order_cost, count(*) as num_orders from med_order group by patientId) as order_table
on pa.ssn = order_table.patientId
;

-- -------------------
-- Stored Procedures
-- -------------------

-- [6] add_patient()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new patient. If the new patient does 
not exist in the person table, then add them prior to adding the patient. 
Ensure that all input parameters are non-null, and that a patient with the given 
SSN does not already exist. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_patient;
delimiter /​/
create procedure add_patient (
	in ip_ssn varchar(40),
    in ip_first_name varchar(100),
    in ip_last_name varchar(100),
    in ip_birthdate date,
    in ip_address varchar(200), 
    in ip_funds integer,
    in ip_contact char(12)
)
sp_main: begin
	IF ip_ssn IS NULL OR ip_first_name IS NULL OR ip_last_name IS NULL OR ip_birthdate IS NULL OR ip_address IS NULL OR ip_funds IS NULL OR ip_contact THEN
		LEAVE sp_main;
	END IF; 
    
	IF EXISTS (SELECT ssn FROM patient WHERE ssn = ip_ssn) THEN 
		LEAVE sp_main; 
	END IF;
    
    IF NOT EXISTS (SELECT ssn FROM person WHERE ssn = ip_ssn) THEN
		INSERT INTO person (ssn, firstName, lastName, birthdate, address)
        VALUES (ip_ssn, ip_first_name, ip_last_name, ip_birthdate, ip_address); 
	END IF; 
    
    INSERT INTO patient (ssn, funds, contact)
    VALUES (ip_ssn, ip_funds, ip_contact); 
end /​/
delimiter ;

-- [7] record_symptom()
-- -----------------------------------------------------------------------------
/* This stored procedure records a new symptom for a patient. Ensure that all input 
parameters are non-null, and that the referenced appointment exists for the given 
patient, date, and time. Ensure that the same symptom is not already recorded for 
that exact appointment. */
-- -----------------------------------------------------------------------------
drop procedure if exists record_symptom;
delimiter /​/
create procedure record_symptom (
	in ip_patientId varchar(40),
    in ip_numDays int,
    in ip_apptDate date,
    in ip_apptTime time,
    in ip_symptomType varchar(100)
)
sp_main: begin
	IF ip_patientId IS NULL OR ip_numDays IS NULL OR ip_apptDate IS NULL OR ip_apptTime IS NULL OR ip_symptomType THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT patientId from appointment WHERE patientID = ip_patientID AND apptDate = ip_apptDate AND apptTime = ip_apptTime) THEN
		LEAVE sp_main; 
	END IF; 
    
    IF EXISTS (SELECT symptomType from symptom WHERE patientID = ip_patientID AND apptDate = ip_apptDate AND apptTime = ip_apptTime AND symptomType = ip_symptomType AND numDays = ip_numDays) THEN
		LEAVE sp_main;
	END IF; 
    
    INSERT INTO symptom (symptomType, numDays, patientId, apptDate, apptTime) 
    VALUES (ip_symptomType, ip_numDays, ip_patientId, ip_apptDate, ip_apptTime);
    
end /​/
delimiter ;

-- [8] book_appointment()
-- -----------------------------------------------------------------------------
/* This stored procedure books a new appointment for a patient at a specific time and date.
The appointment date/time must be in the future (the CURDATE() and CURTIME() functions will
be helpful). The patient must not have any conflicting appointments and must have the funds
to book it on top of any outstanding costs. Each call to this stored procedure must add the 
relevant data to the appointment table if conditions are met. Ensure that all input parameters 
are non-null and reference an existing patient, and that the cost provided is non‑negative. 
Do not charge the patient, but ensure that they have enough funds to cover their current outstanding 
charges and the cost of this appointment.
Uses outstanding_charges_view to evaluate patient charges. */
-- -----------------------------------------------------------------------------
drop procedure if exists book_appointment;
delimiter /​/
create procedure book_appointment (
	in ip_patientId char(11),
	in ip_apptDate date,
    in ip_apptTime time,
	in ip_apptCost integer
)
sp_main: begin

	DECLARE view_funds INT DEFAULT 0; 
    DECLARE view_charges INT DEFAULT 0; 
    
	IF ip_patientId IS NULL OR ip_apptDate IS NULL OR ip_apptTime IS NULL OR ip_apptCost IS NULL THEN
		LEAVE sp_main;
	END IF; 
    
    IF ip_apptCost < 0 THEN 
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT ssn FROM patient WHERE ssn = ip_patientId) THEN 
		LEAVE sp_main; 
	END IF;
    
    IF (ip_apptTime < CURDATE() or ip_apptDate = CURDATE() AND ip_apptTime <= CURTIME()) THEN
		LEAVE sp_main; 
	END IF; 
    
    IF EXISTS (SELECT patientId from appointment WHERE patientId = ip_patientId AND apptDate = ip_apptDate AND apptTime = ip_apptTime) THEN
		LEAVE sp_main; 
	END IF; 
    
    SELECT funds, `Outstanding charges`
    INTO view_funds, view_charges
    FROM er_hospital_management.outstanding_charges_view
    WHERE ssn = ip_patientId; 
    
    IF (view_funds < view_charges + ip_apptCost) THEN
		LEAVE sp_main; 
	END IF; 
    
    INSERT INTO appointment( patientId, cost, apptDate, apptTime)
    VALUES (ip_patientId, ip_apptCost, ip_apptDate, ip_apptTime); 
    

end /​/
delimiter ;



-- [9] place_order()
-- -----------------------------------------------------------------------------
/* This stored procedures places a new order for a patient as ordered by their
doctor. The patient must also have enough funds to cover the cost of the order on 
top of any outstanding costs. Each call to this stored procedure will represent 
either a prescription or a lab report, and the relevant data should be added to the 
corresponding table. Ensure that the order-specific, patient-specific, and doctor-specific 
input parameters are non-null, and that either all the labwork specific input parameters are 
non-null OR all the prescription-specific input parameters are non-null (i.e. if ip_labType 
is non-null, ip_drug and ip_dosage should both be null).
Ensure the inputs reference an existing patient and doctor. 
Ensure that the order number is unique for all orders and positive. Ensure that a cost 
is provided and non‑negative. Do not charge the patient, but ensure that they have 
enough funds to cover their current outstanding charges and the cost of this appointment. 
Ensure that the priority is within the valid range.priority If the order is a prescription, ensure 
the dosage is positive. Ensure that the order is never recorded as both a lab work and a prescription.
The order date inserted should be the current date, and the previous procedure lists a function that
will be required to use in this procedure as well.
Uses outstanding_charges_view to evaluate patient charges. */
-- -----------------------------------------------------------------------------
drop procedure if exists place_order;
delimiter /​/
create procedure place_order (
	in ip_orderNumber int, 
	in ip_priority int,
    in ip_patientId char(11), 
	in ip_doctorId char(11),
    in ip_cost integer,
    in ip_labType varchar(100),
    in ip_drug varchar(100),
    in ip_dosage int
)
sp_main: begin

	DECLARE view_funds INT DEFAULT 0; 
    DECLARE view_charges INT DEFAULT 0; 
    -- checking for  null -- 
	IF ip_orderNumber IS NULL OR ip_priority IS NULL OR ip_patientId IS NULL OR ip_doctorId IS NULL OR ip_cost IS NULL THEN
		LEAVE sp_main;
	END IF; 
    -- making sure only lab specific or drug specific is null, not both -- 
    IF ip_labType IS NULL THEN
		IF ip_drug IS NULL OR ip_dosage IS NULL THEN
			LEAVE sp_main;
		END IF; 
	END iF; 
    
    IF ip_labType IS NOT NULL THEN
		IF ip_drug IS NOT NULL OR ip_dosage IS NOT NULL THEN
			LEAVE sp_main;
		END IF; 
	END IF; 
    
    -- checking if patient exists -- 
    IF NOT EXISTS (SELECT ssn FROM patient WHERE ssn = ip_patientId) THEN
		LEAVE sp_main; 
	END IF; 
    
    -- checking if doctors exists --
    IF NOT EXISTS (SELECT ssn from doctor WHERE ssn = ip_doctorId) THEN
		LEAVE sp_main;
	END IF; 
    

    -- making sure patient has enough funds -- 
    SELECT funds, `Outstanding charges`
    INTO view_funds, view_charges
    FROM er_hospital_management.outstanding_charges_view
    WHERE ssn = ip_patientId; 
    
    IF (view_funds < view_charges + ip_cost) THEN
		LEAVE sp_main; 
	END IF; 
    
    -- checking if order number is positive and unique -- 
    IF ip_orderNumber <= 0 THEN
		LEAVE sp_main;
	END IF; 
    
    IF EXISTS (SELECT orderNumber from med_order WHERE orderNumber = ip_orderNumber) THEN
		LEAVE sp_main; 
	END IF; 
    
    -- cost is provided and non-negative -- 
    IF ip_cost <= 0 THEN
		LEAVE sp_main; 
	END IF; 
    
    -- check if priority is valid -- 
    IF ip_priority < 1 OR ip_priority > 5 THEN
		LEAVE sp_main; 
	END IF; 
    
    -- dosage is positive --
    IF ip_dosage <= 0 THEN 
		LEAVE sp_main; 
	END IF; 
    
    INSERT INTO med_order (orderNumber, orderDate, priority, patientId, doctorId, cost)
    VALUES (ip_orderNumber, CURDATE(), ip_priority, ip_patientId, ip_doctorId, ip_cost);
    
    IF ip_labType IS NOT NULL THEN
		INSERT INTO lab_work (orderNumber, labType)
        VALUES (ip_orderNumber, ip_labType);
	
    ELSE 
		INSERT INTO prescription (orderNumber, drug, dosage)
        VALUES (ip_orderNumber, ip_drug, ip_dosage);
        
	END IF; 
	
    
end /​/
delimiter ;

-- [10] add_staff_to_dept()
-- -----------------------------------------------------------------------------
/* This stored procedure adds a staff member to a department. If they are already
a staff member and not a manager for a different department, they can be assigned
to this new department. If they are not yet a staff member or person, they can be 
assigned to this new department and all other necessary information should be 
added to the database. Ensure that all input parameters are non-null and that the 
Department ID references an existing department. Ensure that the staff member is 
not already assigned to the department. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_staff_to_dept;
delimiter /​/
create procedure add_staff_to_dept (
	in ip_deptId integer,
    in ip_ssn char(11),
    in ip_firstName varchar(100),
	in ip_lastName varchar(100),
    in ip_birthdate date,
    in ip_startdate date,
    in ip_address varchar(200),
    in ip_staffId integer,
    in ip_salary integer
)
sp_main: begin
	IF ip_deptId IS NULL OR ip_ssn IS NULL OR ip_firstName IS NULL OR ip_lastName IS NULL OR ip_birthdate 
    IS NULL OR ip_startdate IS NULL OR ip_address IS NULL OR ip_staffId IS NULL OR ip_salary IS NULL THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT deptId from department WHERE deptId = ip_deptId) THEN
		LEAVE sp_main;
	END IF; 
    
    IF EXISTS (SELECT staffSsn from works_in WHERE staffSsn = ip_staffId AND deptId = ip_deptId) THEN
		LEAVE sp_main;
	END IF; 
    
    IF EXISTS (SELECT manager from department WHERE manager = ip_ssn) THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT ssn from person WHERE ssn = ip_ssn) THEN
		INSERT INTO person(ssn, firstName, lastName, birthdate, address)
        VALUES (ip_ssn, ip_firstName, ip_lastName, ip_birthdate, ip_address);
	END IF;
    
    IF NOT EXISTS (SELECT ssn from staff WHERE ssn = ip_ssn AND staffId = ip_staffId) THEN
		INSERT INTO staff(ssn, staffId, hireDate, salary) 
        VALUES (ip_ssn, ip_staffId, ip_startdate, ip_salary);
	END IF; 
        
	INSERT INTO works_in(staffSsn, deptId)
    VALUES (ip_ssn, ip_deptId);
    
end /​/
delimiter ;

-- [11] add_funds()
-- -----------------------------------------------------------------------------
/* This stored procedure adds funds to an existing patient. The amount of funds
added must be positive. Ensure that all input parameters are non-null and reference 
an existing patient. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_funds;
delimiter /​/
create procedure add_funds (
	in ip_ssn char(11),
    in ip_funds integer
)
sp_main: begin
    
	IF ip_ssn IS NULL OR ip_funds IS NULL THEN
		LEAVE sp_main;
	END IF; 
    
    IF ip_funds <= 0 THEN
		LEAVE sp_main;
	END IF;
    
    IF NOT EXISTS (SELECT ssn from patient WHERE ssn = ip_ssn) THEN
		LEAVE sp_main;
	END IF; 
    
    UPDATE patient
    SET funds = funds + ip_funds
    WHERE ssn = ip_ssn; 
    
end /​/
delimiter ;

-- [12] assign_nurse_to_room()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a nurse to a room. In order to ensure they
are not over-booked, a nurse cannot be assigned to more than 4 rooms. Ensure that 
all input parameters are non-null and reference an existing nurse and room. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_nurse_to_room;
delimiter /​/
create procedure assign_nurse_to_room (
	in ip_nurseId char(11),
    in ip_roomNumber integer
)
sp_main: begin
	IF ip_nurseId IS NULL OR ip_roomNumber IS NULL THEN
		LEAVE sp_main;
	END IF;
    
    IF NOT EXISTS (SELECT ssn from nurse WHERE ssn = ip_nurseId) THEN
		LEAVE sp_main;
	END IF;
    
    IF EXISTS (SELECT roomNumber from room_assignment WHERE roomNumber = ip_roomNumber AND nurseId = ip_nurseId) THEN
		LEAVE sp_main;
	END IF;
    
    IF NOT EXISTS (SELECT roomNumber from room WHERE roomNumber = ip_roomNumber) THEN
		LEAVE sp_main;
	END IF;
    
    IF (SELECT COUNT(*) from room_assignment where nurseId = ip_nurseId) >= 4 THEN
		LEAVE sp_main;
	END IF; 
    
    INSERT INTO room_assignment(roomNumber, nurseId)
    VALUES (ip_roomNumber, ip_nurseId);
    
end /​/
delimiter ;

-- [13] assign_room_to_patient()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a room to a patient. The room must currently be
unoccupied. If the patient is currently assigned to a different room, they should 
be removed from that room. To ensure that the patient is placed in the correct type 
of room, we must also confirm that the provided room type matches that of the 
provided room number. Ensure that all input parameters are non-null and reference 
an existing patient and room. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_room_to_patient;
delimiter /​/
create procedure assign_room_to_patient (
    in ip_ssn char(11),
    in ip_roomNumber int,
    in ip_roomType varchar(100)
)
sp_main: begin
    IF ip_ssn IS NULL OR ip_roomNumber IS NULL OR ip_roomType IS NULL THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT ssn from patient WHERE ssn = ip_ssn) THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT roomNumber from room WHERE roomNumber = ip_roomNumber) THEN
		LEAVE sp_main;
	END IF;
    
    IF NOT EXISTS (SELECT roomNumber from room WHERE roomNumber = ip_roomNumber AND roomType = ip_roomType) THEN
		LEAVE sp_main;
	END IF; 
    
    -- check if room is empty --
    IF EXISTS (SELECT occupiedBy from room WHERE roomNumber = ip_roomNumber AND occupiedBy IS NOT NULL) THEN
		LEAVE sp_main;
	END IF; 
    
    IF EXISTS (SELECT occupiedBy from room WHERE occupiedBy = ip_ssn) THEN
		UPDATE room
        SET occupiedBy = NULL
        WHERE occupiedBy = ip_ssn;
	END IF; 
	
    UPDATE room 
    SET occupiedBy = ip_ssn
    WHERE roomNumber = ip_roomNumber; 
    
end /​/
delimiter ;

-- [14] assign_doctor_to_appointment()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a doctor to an existing appointment. Ensure that no
more than 3 doctors are assigned to an appointment, and that the doctor does not
have commitments to other patients at the exact appointment time. Ensure that all input 
parameters are non-null and reference an existing doctor and appointment. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_doctor_to_appointment;
delimiter /​/
create procedure assign_doctor_to_appointment (
	in ip_patientId char(11),
    in ip_apptDate date,
    in ip_apptTime time,
    in ip_doctorId char(11)
)
sp_main: begin
	IF ip_patientId IS NULL OR ip_apptDate IS NULL OR ip_apptTime IS NULL OR ip_doctorId IS NULL THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT ssn from doctor WHERE ssn = ip_doctorId) THEN
		LEAVE sp_main;
	END IF; 
    
    IF NOT EXISTS (SELECT patientId from appointment WHERE patientId = ip_patientId AND apptDate = ip_apptDate AND apptTime = ip_apptTime) THEN
		LEAVE sp_main;
	END IF; 
    
    IF (SELECT COUNT(*) from appt_assignment WHERE patientId = ip_patientId AND apptTime = ip_apptTime AND apptDate = ip_apptDate) >= 3 THEN
		LEAVE sp_main;
	END IF; 
    -- check if doctor had time conflict at apptdate and time -- 
    IF EXISTS (SELECT apptTime from appt_assignment WHERE doctorId = ip_doctorId AND apptDate = ip_apptDate AND apptTime = ip_apptTime) THEN
		LEAVE sp_main;
	END IF; 
    
	INSERT INTO appt_assignment (patientId, apptDate, apptTime, doctorId)
    VALUES (ip_patientId, ip_apptDate, ip_apptTime, ip_doctorId);
    
end /​/
delimiter ;

-- [15] manage_department()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a staff member as the manager of a department.
The staff member cannot currently be the manager for any departments. They
should be removed from working in any departments except the given
department (make sure the staff member is not the sole employee for any of these 
other departments, as they cannot leave and be a manager for another department otherwise),
for which they should be set as its manager. Ensure that all input parameters are non-null 
and reference an existing staff member and department.
*/
-- -----------------------------------------------------------------------------
drop procedure if exists manage_department;
delimiter /​/
create procedure manage_department (
	in ip_ssn char(11),
    in ip_deptId int
)
sp_main: begin
	IF ip_ssn IS NULL OR ip_deptId IS NULL THEN 
		LEAVE sp_main;
	END IF;
    
    IF NOT EXISTS (SELECT deptId FROM department WHERE deptId = ip_deptId) THEN
		LEAVE sp_main;
	END IF;
    
    IF NOT EXISTS (SELECT ssn FROM staff WHERE ssn = ip_ssn) THEN
		LEAVE sp_main;
	END IF;
    
    -- staff member cannot already be manager of any department
    IF EXISTS (SELECT deptId FROM department WHERE manager = ip_ssn) THEN
		LEAVE sp_main;
    END IF;
    
    -- make sure staff member is not the sole employee in any other department
    IF EXISTS (SELECT w1.deptId FROM works_in w1 WHERE w1.staffSsn = ip_ssn AND w1.deptId <> ip_deptId AND NOT EXISTS (SELECT 1 FROM works_in w2 WHERE w2.deptId = w1.deptId AND w2.staffSsn <> ip_ssn)) THEN
        LEAVE sp_main;
    END IF;
    
    -- remove from all other departments
    DELETE FROM works_in
    WHERE staffSsn = ip_ssn AND deptId <> ip_deptId;
    
    -- ensure they work in this department
    IF NOT EXISTS (SELECT * FROM works_in WHERE staffSsn = ip_ssn AND deptId = ip_deptId) THEN
        INSERT INTO works_in (staffSsn, deptId)
        VALUES (ip_ssn, ip_deptId);
    END IF;
    
    -- set as manager of this department
    UPDATE department
    SET manager = ip_ssn
    WHERE deptId = ip_deptId;
    
end /​/
delimiter ;


-- [16] release_room()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a patient from a given room. Ensure that 
the input room number is non-null and references an existing room.  */
-- -----------------------------------------------------------------------------
drop procedure if exists release_room;
delimiter /​/
create procedure release_room (
    in ip_roomNumber int
)
sp_main: begin
	IF ip_roomNumber IS NULL THEN 
		leave sp_main; 
	END IF;
    
    IF NOT EXISTS(select roomNumber from room where roomNumber = ip_roomNumber) THEN
		leave sp_main;
	END IF;
    
    UPDATE room
    set occupiedBy = NULL
    where roomNumber = ip_roomNumber;
    
    
end /​/
delimiter ;

-- [17] remove_patient()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a given patient. If the patient has any pending
orders or remaining appointments (regardless of time), they cannot be removed.
If the patient is not a staff member, they then must be completely removed from 
the database. Ensure all data relevant to this patient is removed. Ensure that the 
input SSN is non-null and references an existing patient. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_patient;
delimiter /​/
create procedure remove_patient (
	in ip_ssn char(11)
)
sp_main: begin
	IF ip_ssn IS NULL THEN 
		leave sp_main; 
	END IF;
    
    -- checks that patient is an existing patient -- 
    IF NOT EXISTS(select ssn from patient where ssn = ip_ssn) THEN
		leave sp_main;
	END IF;
    
    -- 
    IF EXISTS(select patientId from appointment where ip_ssn = patientId) THEN
		leave sp_main;
	END IF;
    
    IF EXISTS(select patientId from med_order where ip_ssn = patientId) THEN
		leave sp_main;
	END IF;
    
    -- removes patient and all relevant data after checking they are not part of staff--
    IF NOT EXISTS (SELECT ssn from staff WHERE ssn = ip_ssn) THEN
		DELETE from person where ssn = ip_ssn;
	END IF; 
    
end /​/
delimiter ;

-- remove_staff()
-- Lucky you, we provided this stored procedure to you because it was more complex
-- this implementation. The procedure is used as a supporting operation
-- in the next procedure!
-- -----------------------------------------------------------------------------
/* This stored procedure removes a given staff member. If the staff member is a 
manager, they are not removed. If the staff member is a nurse, all rooms
they are assigned to have a remaining nurse if they are to be removed. 
If the staff member is a doctor, all appointments they are assigned to have
a remaining doctor and they have no pending orders if they are to be removed.
If the staff member is not a patient, then they are completely removed from 
the database. All data relevant to this staff member is removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_staff;
delimiter /​/
create procedure remove_staff (
	in ip_ssn char(11)
)
sp_main: begin
	-- ensure parameters are not null
    if ip_ssn is null then
		leave sp_main;
	end if;
    
	-- ensure staff member exists
	if not exists (select ssn from staff where ssn = ip_ssn) then
		leave sp_main;
	end if;
	
    -- if staff member is a nurse
    if exists (select ssn from nurse where ssn = ip_ssn) then
	if exists (
		select 1
		from (
			 -- Get all rooms assigned to the nurse
			 select roomNumber
			 from room_assignment
			 where nurseId = ip_ssn
		) as my_rooms
		where not exists (
			 -- Check if there is any other nurse assigned to that room
			 select 1
			 from room_assignment 
			 where roomNumber = my_rooms.roomNumber
			   and nurseId <> ip_ssn
		)
	)
	then
		leave sp_main;
	end if;
		
        -- remove this nurse from room_assignment and nurse tables
		delete from room_assignment where nurseId = ip_ssn;
		delete from nurse where ssn = ip_ssn;
	end if;
	
    -- if staff member is a doctor
	if exists (select ssn from doctor where ssn = ip_ssn) then
		-- ensure the doctor does not have any pending orders
		if exists (select * from med_order where doctorId = ip_ssn) then 
			leave sp_main;
		end if;
		
		-- ensure all appointments assigned to this doctor have remaining doctors assigned
		if exists (
		select 1
		from (
			 -- Get all appointments assigned to ip_ssn
			 select patientId, apptDate, apptTime
			 from appt_assignment
			 where doctorId = ip_ssn
		) as ip_appointments
		where not exists (
			 -- For the same appointment, check if there is any other doctor assigned
			 select 1
			 from appt_assignment 
			 where patientId = ip_appointments.patientId
			   and apptDate = ip_appointments.apptDate
			   and apptTime = ip_appointments.apptTime
			   and doctorId <> ip_ssn
		)
	)
	then
		leave sp_main;
	end if;
        
		-- remove this doctor from appt_assignment and doctor tables
		delete from appt_assignment where doctorId = ip_ssn;
		delete from doctor where ssn = ip_ssn;
	end if;
    
    -- remove staff member from works_in and staff tables
    delete from works_in where staffSsn = ip_ssn;
    delete from staff where ssn = ip_ssn;

	-- ensure staff member is not a patient
	if exists (select * from patient where ssn = ip_ssn) then 
		leave sp_main;
	end if;
    
    -- remove staff member from person table
	delete from person where ssn = ip_ssn;
end /​/
delimiter ;

-- [18] remove_staff_from_dept()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a staff member from a department. If the staff
member is the manager of that department, they cannot be removed. If the staff
member, after removal, is no longer working for any departments, they should then 
also be removed as a staff member, following all logic in the remove_staff procedure. 
Ensure that all input parameters are non-null and that the given person works for
the given department. Ensure that the department will have at least one staff member 
remaining after this staff member is removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_staff_from_dept;
delimiter /​/
create procedure remove_staff_from_dept (
	in ip_ssn char(11),
    in ip_deptId integer
)
sp_main: begin
	if ip_ssn is null OR ip_deptId is null then
		leave sp_main;
	end if;
    
    if not exists(select staffSsn from works_in where staffSsn = ip_ssn and deptId = ip_deptId) then
		leave sp_main;
	end if;
    
    if exists(select manager from department where manager = ip_ssn and deptId = ip_deptId) then
		leave sp_main;
	end if;
    
    if not exists(select 1 from works_in where deptId = ip_deptId and staffSsn <> ip_ssn) then
		leave sp_main;
    end if;
    
   delete from works_in where staffSsn = ip_ssn AND deptId = ip_deptId;
    
    if not exists(select staffSsn from works_in where staffSsn = ip_ssn) then
		call remove_staff(ip_ssn);
	end if;
    
end /​/
delimiter ;

-- [19] complete_appointment()
-- -----------------------------------------------------------------------------
/* This stored procedure completes an appointment given its date, time, and patient SSN.
The completed appointment and any related information should be removed 
from the system, and the patient should be charged accordingly. Ensure that all 
input parameters are non-null and that they reference an existing appointment. */
-- -----------------------------------------------------------------------------
drop procedure if exists complete_appointment;
delimiter /​/
create procedure complete_appointment (
	in ip_patientId char(11),
    in ip_apptDate DATE, 
    in ip_apptTime TIME
)
sp_main: begin
	
    declare apptCost int default 0;
    
	if ip_patientId is null OR ip_apptDate is null or ip_apptTime is null then
		leave sp_main;
	end if;
    
    if not exists(select patientId from appointment where ip_patientId = patientId AND ip_apptDate = apptDate AND ip_apptTime = apptTime) then
		leave sp_main;
	end if;
    
    select cost
    into apptCost 
    from appointment where patientId = ip_patientId and apptDate= ip_apptDate  and apptTime = apptTime;
    
    Update patient 
    set funds = funds - apptCost 
    where ip_patientId = ssn;
    
	delete from appointment where ip_patientId = patientId and ip_apptDate = apptDate and ip_apptTime = apptTime;

    
    
end /​/
delimiter ;

-- [20] complete_orders()
-- -----------------------------------------------------------------------------
/* This stored procedure attempts to complete a certain number of orders based on the 
passed in value. Orders should be completed in order of their priority, from highest to
lowest. If multiple orders have the same priority, the older dated one should be 
completed first. Any completed orders should be removed from the system, and patients 
should be charged accordingly. Ensure that there is a non-null number of orders
passed in, and complete as many as possible up to that limit. */
-- -----------------------------------------------------------------------------
drop procedure if exists complete_orders;
delimiter /​/
create procedure complete_orders (
	in ip_num_orders integer
)
sp_main: begin
	DECLARE order_cost INT DEFAULT 0;
    DECLARE order_num INT DEFAULT 0;
    DECLARE patient_id CHAR(11) DEFAULT NULL; 
    
	IF ip_num_orders IS NULL THEN 
		LEAVE sp_main;
	END IF; 
    
    WHILE ip_num_orders > 0 DO 
		SELECT cost, orderNumber, patientId
        INTO order_cost, order_num, patient_id
        FROM med_order
        ORDER BY priority desc, orderDate asc
        LIMIT 1; 
        
        IF order_num IS NULL THEN
			LEAVE sp_main;
		END IF; 
        
        -- charged the patient -- 
        Update patient 
		set funds = funds - order_cost
		where ssn = patient_id;
        
        DELETE FROM med_order
        WHERE orderNumber = order_num; 
        
        SET ip_num_orders = ip_num_orders - 1; 
        
	END WHILE; 
end /​/
delimiter ;
