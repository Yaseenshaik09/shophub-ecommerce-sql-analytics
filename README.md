
# ShopHub – E-Commerce SQL Analytics Project

## Project Overview
ShopHub is an end-to-end SQL analytics project built using the Brazilian E-Commerce Public Dataset by Olist.

The project covers relational database design, data cleaning, data quality validation, business analysis, advanced SQL techniques, stored procedures, and query optimization using MySQL.

## Tools & Technologies
- MySQL 8.0
- MySQL Workbench
- SQL
- GitHub

## Project Structure
```text
ShopHub_Ecommerce_SQL_Project/
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_data_cleaning.sql
│   ├── 03_data_quality_checks.sql
│   ├── 03_queries.sql
│   ├── 04_optimization.sql
│   └── README.md
│
├── documentation/
│   ├── ShopHub_ER_Diagram.png
│   ├── ShopHub_Data_Dictionary.docx
│   ├── Part_A_Data_Quality_Report.docx
│   ├── ShopHub_Optimization_Report.docx
│   └── README.md
│
└── README.md
```

## Project Work

### 1. Database Design
- Designed a relational schema with 9 tables.
- Implemented primary keys, foreign keys, and indexes.
- Created an Entity Relationship Diagram (ERD).
- Prepared a data dictionary.

### 2. Data Cleaning & Quality Checks
- Validated missing values and duplicate records.
- Checked referential integrity and orphan records.
- Investigated timestamp and payment inconsistencies.
- Documented data quality findings and limitations.

### 3. Business & Customer Analytics
- Customer purchase behavior and lifetime spending.
- Monthly revenue and month-over-month analysis.
- Product and category performance.
- Seller performance and customer segmentation.
- Market basket analysis and shipping performance.

### 4. Advanced SQL
- Common Table Expressions (CTEs).
- Recursive CTEs.
- Window functions: LAG, RANK, and running totals.
- Rolling averages and consecutive-month analysis.
- ROLLUP for aggregated reporting.

### 5. Stored Procedures & Query Optimization
- Created a parameterized order discount procedure.
- Added input validation and error handling.
- Used EXPLAIN ANALYZE to inspect query execution.
- Tested a composite index and evaluated its performance impact.

## Key Project Findings
- Analyzed approximately 1.59 million records across 9 tables.
- Identified 2,997 customer identities with multiple customer records.
- Found payment reconciliation differences requiring further investigation.
- Evaluated delivery performance across customer states.
- Tested an index that did not improve the measured query runtime and removed it.

## Dataset
Brazilian E-Commerce Public Dataset by Olist.

## Important Notes
- The dataset does not contain customer email or name fields, so email-based identity checks were not possible.
- The dataset does not provide a product category hierarchy; recursive hierarchy analysis is demonstrated using sample hierarchy data.
- Payment discrepancies are treated as reconciliation exceptions, not confirmed fraud.
- SQL scripts are provided for review and execution. Run them in the documented order and review any data-changing statements before execution.

## Project Status
**Completed – SQL analytics and optimization tasks documented.**

