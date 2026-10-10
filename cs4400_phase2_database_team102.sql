-- Emergency Room Management Database: schema and sample records
-- Contributors: Jayani Mannam, Neha Kunche, Amrin Khimani

/* Standard preamble */

set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'er_management';
drop database if exists er_management;
create database if not exists er_management;
use er_management;

-- =======================
-- ====== TABLES =========
-- =======================

CREATE TABLE Person (
  ssn       CHAR(11) PRIMARY KEY,
  firstName VARCHAR(40) NOT NULL,
  lastName  VARCHAR(40) NOT NULL,
  birthdate DATE,
  address   VARCHAR(200)
);

CREATE TABLE Patient (
  ssn     CHAR(11) PRIMARY KEY,
  contact VARCHAR(20),
  funds   DECIMAL(10,2),
  CONSTRAINT fk_patient_person
    FOREIGN KEY (ssn) REFERENCES Person(ssn)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

CREATE TABLE Staff (
  staffID  VARCHAR(16) PRIMARY KEY,
  ssn      CHAR(11) NOT NULL UNIQUE,
  salary   DECIMAL(10,2),
  hireDate DATE,
  CONSTRAINT fk_staff_person
    FOREIGN KEY (ssn) REFERENCES Person(ssn)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

-- Doctor must always have a Staff; NOT NULL + RESTRICT
CREATE TABLE Doctor (
  staffID        VARCHAR(16) NOT NULL,
  licenseNumber  VARCHAR(60) NOT NULL,
  experience     INT,
  CONSTRAINT uq_doctor_license UNIQUE (licenseNumber),
  CONSTRAINT uq_doctor_staff   UNIQUE (staffID),
  CONSTRAINT fk_doctor_staff
    FOREIGN KEY (staffID) REFERENCES Staff(staffID)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE TABLE Nurse (
  staffID       VARCHAR(16) NULL,
  shiftType     VARCHAR(40),
  regExpiration DATE NOT NULL,
  CONSTRAINT uq_nurse_staff UNIQUE (staffID),
  CONSTRAINT fk_nurse_staff
    FOREIGN KEY (staffID) REFERENCES Staff(staffID)
    ON UPDATE RESTRICT
    ON DELETE SET NULL
);

-- Department manager cannot be NULL; RESTRICT on delete/update
CREATE TABLE Department (
  deptID INT PRIMARY KEY,
  mgrID  VARCHAR(16) NOT NULL,
  name   VARCHAR(80) NOT NULL,
  CONSTRAINT uq_department_name UNIQUE (name),
  CONSTRAINT uq_department_mgr  UNIQUE (mgrID),
  CONSTRAINT fk_department_mgr
    FOREIGN KEY (mgrID) REFERENCES Staff(staffID)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

-- prevent duplicate memberships
CREATE TABLE worksIn (
  staffID VARCHAR(16) NOT NULL,
  deptID  INT        NOT NULL,
  PRIMARY KEY (staffID, deptID),
  CONSTRAINT fk_worksin_staff
    FOREIGN KEY (staffID) REFERENCES Staff(staffID)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,
  CONSTRAINT fk_worksin_dept
    FOREIGN KEY (deptID) REFERENCES Department(deptID)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

CREATE TABLE Room (
  number INT PRIMARY KEY,
  type   VARCHAR(40) NOT NULL,
  deptID INT         NOT NULL,
  pssn   CHAR(11),
  CONSTRAINT fk_room_dept
    FOREIGN KEY (deptID) REFERENCES Department(deptID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_room_patient
    FOREIGN KEY (pssn) REFERENCES Patient(ssn)
    ON UPDATE RESTRICT
    ON DELETE SET NULL
);

-- dstaffID must be NOT NULL; use RESTRICT
CREATE TABLE `Order` (
  orderNumber INT PRIMARY KEY,
  priority    INT CHECK (priority BETWEEN 1 AND 5),
  date        DATE,
  cost        DECIMAL(10,2),
  dstaffID    VARCHAR(16) NOT NULL,
  pssn        CHAR(11)    NOT NULL,
  CONSTRAINT fk_order_doctor
    FOREIGN KEY (dstaffID) REFERENCES Doctor(staffID)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT fk_order_patient
    FOREIGN KEY (pssn) REFERENCES Patient(ssn)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

CREATE TABLE Prescription (
  orderNumber INT PRIMARY KEY,
  drugType    VARCHAR(60) NOT NULL,
  dosage      VARCHAR(60) NOT NULL,
  CONSTRAINT fk_prescription_order
    FOREIGN KEY (orderNumber) REFERENCES `Order`(orderNumber)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

CREATE TABLE LabWork (
  orderNumber INT PRIMARY KEY,
  type        VARCHAR(60) NOT NULL,
  CONSTRAINT fk_labwork_order
    FOREIGN KEY (orderNumber) REFERENCES `Order`(orderNumber)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

-- column name 'type' (singular); all required
CREATE TABLE Appointment (
  pssn     CHAR(11)      NOT NULL,
  booking  INT           NOT NULL,
  date     DATE          NOT NULL,
  time     TIME          NOT NULL,
  symptoms VARCHAR(200)  NOT NULL,
  numDays  INT           NOT NULL,
  type     VARCHAR(40)   NOT NULL,
  cost     DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (pssn, booking),
  CONSTRAINT fk_appointment_patient
    FOREIGN KEY (pssn) REFERENCES Patient(ssn)
    ON UPDATE RESTRICT
    ON DELETE CASCADE
);

CREATE TABLE scheduledFor (
  pssn     CHAR(11)   NOT NULL,
  booking  INT        NOT NULL,
  dstaffID VARCHAR(16)NOT NULL,
  CONSTRAINT fk_sched_appt
    FOREIGN KEY (pssn, booking) REFERENCES Appointment(pssn, booking)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,
  CONSTRAINT fk_sched_doctor
    FOREIGN KEY (dstaffID) REFERENCES Doctor(staffID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);

CREATE TABLE Assigned (
  number   INT         NOT NULL,
  nstaffID VARCHAR(16) NOT NULL,
  CONSTRAINT fk_assigned_room
    FOREIGN KEY (number)  REFERENCES Room(number)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_assigned_nurse
    FOREIGN KEY (nstaffID) REFERENCES Nurse(staffID)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

-- =======================
-- ====== DATA ===========
-- =======================

-- PERSON
INSERT INTO Person (ssn, firstName, lastName, birthdate, address) VALUES
('909-10-1111','Maria','Alvarez','1987-03-22','81 Peachtree Pl NE, Atlanta, GA 30309'),
('323-44-5555','Dr.','Marcus Lee','1979-12-11','1420 Oak Terrace, Decatur, GA 30030'),
('636-77-8888','Olivia','Bennett','1970-01-01','950 W Peachtree, Atlanta, GA 30308'),
('858-99-0000','Chloe','Davis','1975-06-24','500 North Ave, Atlanta, GA 30302'),
('969-00-1112','Liam','Foster','1980-12-14','670 Piedmont Ave, Atlanta, GA 30303'),
('212-33-4444','Dr.','Priya Shah','1986-06-06','1000 Howell Mill Rd, Atlanta, GA 30303'),
('101-22-3030','Dr.','Emily Park','1997-05-19','848 Spring St NW, Atlanta, GA 30308'),
('454-66-7777','Dr.','Omar Haddad','1980-05-01','108 Main St, Atlanta, GA 30308'),
('888-77-6666','Dr.','Sarah Mitchell','1975-06-10','742 Maple Avenue, Decatur, GA 30030'),
('135-79-0000','Dr.','David Thompson','1980-08-15','925 Brookside Drive, Marietta, GA 30062'),
('204-60-8010','Dr.','Laura Chen','1978-04-22','488 Willow Creek Lane, Johns Creek, GA 30097'),
('987-65-4321','Dr.','Matthew Nguyen','1970-03-01','3100 Briarcliff Road, Atlanta, GA 30329'),
('300-40-5000','David','Taylor','1985-01-10','124 Oakwood Circle, Smyrna, GA 30080'),
('800-50-7676','Ethan','Brooks','1987-07-18','275 Pine Hollow Drive, Roswell, GA 30075'),
('103-05-7090','Hannah','Wilson','1990-09-25','889 Laurel Springs Lane, Alpharetta, GA 30022');

-- PATIENT
INSERT INTO Patient (ssn, contact, funds) VALUES
('909-10-1111','404-555-1010',1800.00),
('323-44-5555','470-555-2020',2400.00);

-- STAFF (ssn NOT NULL + UNIQUE)
INSERT INTO Staff (staffID, ssn, salary, hireDate) VALUES
('720301.0','636-77-8888', 92000.00,'2023-02-01'),
('720303.0','858-99-0000', 93500.00,'2021-11-30'),
('720304.0','969-00-1112', 90500.00,'2020-08-20'),
('510201.0','212-33-4444',265000.00,'2016-08-19'),
('510202.0','323-44-5555',238000.00,'2019-09-03'),
('510203.0','101-22-3030',312000.00,'2014-02-27'),
('510204.0','454-66-7777',328000.00,'2012-11-05'),
('511283.0','987-65-4321',450000.00,'2010-01-01'),
('936497.0','300-40-5000', 79000.00,'2021-09-15'),
('783404.0','800-50-7676', 91000.00,'2017-11-23'),
('416799.0','103-05-7090', 85000.00,'2019-08-13'),
-- Scenario doctors as Staff with real, unique SSNs
('107435','888-77-6666',200000.00,'2017-03-11'),
('237432','135-79-0000',250000.00,'2019-02-05'),
('902385','204-60-8010',300000.00,'2012-05-30');

-- DOCTOR
INSERT INTO Doctor (staffID, licenseNumber, experience) VALUES
('510201.0','77231.0',11),
('510202.0','88342.0',7),
('510203.0','66125.0',15),
('510204.0','99473.0',18),
('511283.0','56789.0',20),
('107435','89012',16),
('237432','23456',8),
('902385','34567',12);

-- NURSE
INSERT INTO Nurse (staffID, shiftType, regExpiration) VALUES
('720301.0','Morning','2027-01-31'),
('720303.0','Night','2026-05-31'),
('720304.0','Afternoon','2026-12-31'),
('936497.0',NULL,'2026-06-01'),
('783404.0',NULL,'2026-07-15'),
('416799.0',NULL,'2026-05-31');

-- DEPARTMENT (mgrID NOT NULL + UNIQUE) — managers must already exist in Staff
INSERT INTO Department (deptID, mgrID, name) VALUES
(7,  '510201.0','Cardiology'),
(9,  '510202.0','Neurology'),
(11, '107435',  'Primary Care'),
(4,  '902385',  'Ophthalmology');

-- worksIn (PK prevents duplicates; managers also work in their dept)
INSERT INTO worksIn (staffID, deptID) VALUES
('720301.0',9),
('720301.0',7),
('720303.0',7),
('720304.0',7),
('510201.0',7),
('510202.0',9),
('510203.0',7),
('510204.0',9),
('107435',11),
('237432',4),
('902385',4),
('936497.0',4),
('783404.0',4),
('416799.0',11);

-- ROOM for existing patients (insert Christopher later before Room 1108)
INSERT INTO Room (number, type, deptID, pssn) VALUES
(3102,'Shared', 9,'909-10-1111'),
(1421,'Private',7,'323-44-5555');

-- ===== Scenario: Christopher Davis (must be Person + Patient before Room 1108) =====
INSERT INTO Person (ssn, firstName, lastName, birthdate, address)
VALUES ('123-45-6789','Christopher','Davis','1965-02-25','1234 Peach Street, Atlanta, GA 30305');
INSERT INTO Patient (ssn, contact, funds)
VALUES ('123-45-6789','470-321-6543',2000.00);

-- Now rooms that reference Christopher / Primary Care
INSERT INTO Room (number, type, deptID, pssn) VALUES
(1108,'Private',4,'123-45-6789'),
(908, 'Shared', 11, NULL);

-- APPOINTMENTS / SCHEDULING
INSERT INTO Appointment (pssn, booking, date, time, symptoms, numDays, type, cost) VALUES
('909-10-1111',1,'2025-09-15','09:20:00','Migraine',5,'',520.00);
INSERT INTO scheduledFor (pssn, booking, dstaffID) VALUES ('909-10-1111',1,'510202.0');

INSERT INTO Appointment (pssn, booking, date, time, symptoms, numDays, type, cost) VALUES
('323-44-5555',1,'2025-09-15','14:05:00','Chest tightness',1,'',460.00);
INSERT INTO scheduledFor (pssn, booking, dstaffID) VALUES ('323-44-5555',1,'510203.0');

INSERT INTO Appointment (pssn, booking, date, time, symptoms, numDays, type, cost) VALUES
('123-45-6789',1,'2025-03-15','15:00:00','blurry vision',7,'',300.00);
INSERT INTO scheduledFor (pssn, booking, dstaffID) VALUES ('123-45-6789',1,'107435');

INSERT INTO Appointment (pssn, booking, date, time, symptoms, numDays, type, cost) VALUES
('123-45-6789',2,'2025-04-27','11:30:00','blurry vision; sensitivity to light; halos',40,'',750.00);
INSERT INTO scheduledFor (pssn, booking, dstaffID) VALUES ('123-45-6789',2,'237432');
INSERT INTO scheduledFor (pssn, booking, dstaffID) VALUES ('123-45-6789',2,'902385');

-- ORDERS / SUBTYPES (doctor must exist; RESTRICT prevents deleting a doctor with orders)
INSERT INTO `Order` (orderNumber, priority, date, cost, dstaffID, pssn) VALUES
(3100451,2,'2025-09-15',25.00,'510202.0','909-10-1111');
INSERT INTO Prescription (orderNumber, drugType, dosage) VALUES
(3100451,'Sumatriptan','50 mg');

INSERT INTO `Order` (orderNumber, priority, date, cost, dstaffID, pssn) VALUES
(3750129,1,'2025-09-15',95.00,'510203.0','323-44-5555');
INSERT INTO LabWork (orderNumber, type) VALUES
(3750129,'Cardiac enzyme panel');

INSERT INTO `Order` (orderNumber, priority, date, cost, dstaffID, pssn)
VALUES (1560238,2,'2025-04-27',15.00,'237432','123-45-6789');
INSERT INTO Prescription (orderNumber, drugType, dosage)
VALUES (1560238,'Pain Reliever','800 mg');

INSERT INTO `Order` (orderNumber, priority, date, cost, dstaffID, pssn)
VALUES (1561902,1,'2025-05-01',50.00,'237432','123-45-6789');
INSERT INTO LabWork (orderNumber, type) VALUES (1561902,'Blood Test');

-- Nurse assignments
INSERT INTO Assigned (number, nstaffID) VALUES
(3102,'720301.0'),
(1421,'720303.0'),
(1421,'720304.0'),
(908, '720301.0'),
(1108,'720304.0');
