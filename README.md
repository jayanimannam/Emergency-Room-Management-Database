# Emergency Room Management Database

A relational database project for tracking patients, medical staff, departments, rooms, appointments, treatment orders, and billing-related activity in a hospital emergency-room setting.

## What it covers

- Relational tables for patients, staff, doctors, nurses, departments, and room assignments
- Appointment scheduling, prescription orders, and lab work
- Foreign-key constraints and sample records for testing the schema
- SQL views for room assignments, symptoms, medical staff, department staffing, and outstanding patient charges
- Stored procedures for patient registration, appointment booking, room and staff assignment, orders, funds, and completion workflows

## Technologies

MySQL, SQL, relational database design, views, stored procedures, joins, foreign keys, and data integrity constraints.

## Repository files

- `cs4400_phase2_database_team102.sql` — creates the `er_management` database, defines tables and relationships, and inserts sample records.
- `Phase III SP+Views Template.sql` — defines reporting views and stored procedures for `er_hospital_management`. The filename is retained for compatibility with existing references.

## Database design

The schema script includes `Person`, `Patient`, `Staff`, `Doctor`, `Nurse`, `Department`, `worksIn`, `Room`, `Order`, `Prescription`, `LabWork`, `Appointment`, `scheduledFor`, and `Assigned`. Relationships are enforced with primary and foreign keys, including links between people and patients, medical staff and departments, orders and patients, and rooms and occupants.

## Views

- `room_wise_view` — room occupants and medical staff assignments.
- `symptoms_overview_view` — appointment information and associated symptoms.
- `medical_staff_view` — doctors, nurses, departments, and assignment counts.
- `department_view` — department staffing summaries.
- `outstanding_charges_view` — patient appointment and order charges.

## Stored procedures

The routines script includes procedures named `add_patient`, `record_symptom`, `book_appointment`, `place_order`, `add_staff_to_dept`, `add_funds`, `assign_nurse_to_room`, `assign_room_to_patient`, `assign_doctor_to_appointment`, `manage_department`, `release_room`, `remove_patient`, `remove_staff`, `remove_staff_from_dept`, `complete_appointment`, and `complete_orders`.

## Setup and execution

1. Use a MySQL-compatible SQL client, such as MySQL Workbench.
2. Inspect and run the schema and sample-data script first to create `er_management`.
3. Review the differences described below before attempting to apply the views/procedures script. It cannot be assumed to work against the schema script as-is.
4. Once the database names, table names, columns, and keys are reconciled, execute the compatible views and procedure definitions and test them against sample data.

## Important compatibility note

**The two SQL files are not a ready-to-run unified deployment.** The schema file creates `er_management` while the views/procedures file uses `er_hospital_management`. The later script also references different table and column names (for example, `room_assignment` vs. `Assigned`, `appt_assignment` vs. `scheduledFor`, and `med_order` vs. `Order`). These differences must be reconciled before the scripts will work together. The underlying SQL logic has been preserved during this documentation cleanup; no execution or end-to-end validation has been performed.

## Contributors

Jayani Mannam, Neha Kunche, and Amrin Khimani.
