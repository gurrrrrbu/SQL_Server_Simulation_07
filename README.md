# Simulation 7 - Dynamic SQL Execution and Security (DSL)

# Course
SQL Server Development

# Database
AdventureWorks2022

# Overview
This simulation demonstrates secure and vulnerable dynamic SQL execution in SQL Server using AdventureWorks2022. The project includes execution logging, input validation, summary reporting, and comparison of secure and insecure SQL construction methods.

# Procedures Included

1. Reporting.usp_SecureSalesReport
This procedure generates a dynamic sales report using optional parameters. It uses sp_executesql and parameterized SQL to prevent SQL injection. It also validates unsafe input and invalid date ranges.

2. Reporting.usp_VulnerableSalesReport
This procedure generates the same report but uses direct string concatenation with EXEC(@SQL). It is intentionally vulnerable and is used to demonstrate how SQL injection can affect query behavior.

# Logging
All executions are recorded in Reporting.ExecutionLog with:
- Procedure name
- Execution status
- Parameter values
- Execution time

# Execution Summary
A summary view named Reporting.vExecutionSummary reports:
- Total executions
- Successful executions
- Failed executions
- Rejected executions

# Testing Steps
1. Execute the secure procedure with no filters.
2. Execute the secure procedure with one filter.
3. Execute the secure procedure with multiple filters.
4. Execute the secure procedure with invalid date range.
5. Execute the secure procedure with unsafe input.
6. Execute the vulnerable procedure with normal input.
7. Execute the vulnerable procedure with injection input.
8. Query the log table.
9. Query the execution summary view.

# Expected Results
- The secure procedure should return correct filtered results.
- Unsafe input should be rejected by the secure procedure.
- The vulnerable procedure should show changed behavior when injection input is used.
- All executions should be logged.
- The summary view should display execution totals by status.
- README.md
- Screenshots/
- Report/Simulation7_Report.docx
