USE AdventureWorks2022;
GO

USE AdventureWorks2022;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'Reporting'
)
BEGIN
    EXEC('CREATE SCHEMA Reporting');
END
GO

IF OBJECT_ID('Reporting.ExecutionLog', 'U') IS NULL
BEGIN
    CREATE TABLE Reporting.ExecutionLog
    (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        ProcedureName NVARCHAR(200) NOT NULL,
        ExecutionStatus NVARCHAR(50) NOT NULL,
        ParameterValues NVARCHAR(MAX) NULL,
        ExecutionTime DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

SELECT TOP 20
    st.Name AS TerritoryName,
    CASE 
        WHEN pp.FirstName IS NULL THEN 'No Salesperson'
        ELSE pp.FirstName + ' ' + pp.LastName
    END AS SalesPersonName,
    pc.Name AS ProductCategory,
    soh.OrderDate,
    sod.LineTotal AS TotalSalesAmount,
    sod.OrderQty AS OrderQuantity
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
LEFT JOIN Sales.SalesPerson sp
    ON soh.SalesPersonID = sp.BusinessEntityID
LEFT JOIN Person.Person pp
    ON sp.BusinessEntityID = pp.BusinessEntityID
LEFT JOIN Sales.SalesTerritory st
    ON soh.TerritoryID = st.TerritoryID
JOIN Production.Product p
    ON sod.ProductID = p.ProductID
LEFT JOIN Production.ProductSubcategory psc
    ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc
    ON psc.ProductCategoryID = pc.ProductCategoryID;



CREATE OR ALTER PROCEDURE Reporting.usp_SecureSalesReport
    @TerritoryName NVARCHAR(100) = NULL,
    @SalesPersonName NVARCHAR(100) = NULL,
    @ProductCategory NVARCHAR(100) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Params NVARCHAR(MAX);
    DECLARE @ParameterValues NVARCHAR(MAX);

    SET @ParameterValues =
        CONCAT(
            'TerritoryName=', ISNULL(@TerritoryName, 'NULL'),
            '; SalesPersonName=', ISNULL(@SalesPersonName, 'NULL'),
            '; ProductCategory=', ISNULL(@ProductCategory, 'NULL'),
            '; StartDate=', ISNULL(CONVERT(NVARCHAR(30), @StartDate), 'NULL'),
            '; EndDate=', ISNULL(CONVERT(NVARCHAR(30), @EndDate), 'NULL')
        );

    -- Validation: unsafe patterns
    IF (@TerritoryName IS NOT NULL AND
        (@TerritoryName LIKE '%--%' OR @TerritoryName LIKE '%;%' OR UPPER(@TerritoryName) LIKE '%DROP%' OR UPPER(@TerritoryName) LIKE '%EXEC%'))
       OR
       (@SalesPersonName IS NOT NULL AND
        (@SalesPersonName LIKE '%--%' OR @SalesPersonName LIKE '%;%' OR UPPER(@SalesPersonName) LIKE '%DROP%' OR UPPER(@SalesPersonName) LIKE '%EXEC%'))
       OR
       (@ProductCategory IS NOT NULL AND
        (@ProductCategory LIKE '%--%' OR @ProductCategory LIKE '%;%' OR UPPER(@ProductCategory) LIKE '%DROP%' OR UPPER(@ProductCategory) LIKE '%EXEC%'))
    BEGIN
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutionStatus, ParameterValues)
        VALUES ('Reporting.usp_SecureSalesReport', 'Rejected', @ParameterValues);

        PRINT 'Unsafe input detected. Execution rejected.';
        RETURN;
    END;

    -- Validation: date range
    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate > @EndDate
    BEGIN
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutionStatus, ParameterValues)
        VALUES ('Reporting.usp_SecureSalesReport', 'Rejected', @ParameterValues);

        PRINT 'Invalid date range. Execution rejected.';
        RETURN;
    END;

    SET @SQL = '
    SELECT
        st.Name AS TerritoryName,
        CASE 
            WHEN pp.FirstName IS NULL THEN ''No Salesperson''
            ELSE pp.FirstName + '' '' + pp.LastName
        END AS SalesPersonName,
        pc.Name AS ProductCategory,
        soh.OrderDate,
        sod.LineTotal AS TotalSalesAmount,
        sod.OrderQty AS OrderQuantity
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    LEFT JOIN Sales.SalesPerson sp
        ON soh.SalesPersonID = sp.BusinessEntityID
    LEFT JOIN Person.Person pp
        ON sp.BusinessEntityID = pp.BusinessEntityID
    LEFT JOIN Sales.SalesTerritory st
        ON soh.TerritoryID = st.TerritoryID
    JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    LEFT JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
    WHERE 1 = 1';

    IF @TerritoryName IS NOT NULL
        SET @SQL += ' AND st.Name = @TerritoryName';

    IF @SalesPersonName IS NOT NULL
        SET @SQL += ' AND (pp.FirstName + '' '' + pp.LastName) = @SalesPersonName';

    IF @ProductCategory IS NOT NULL
        SET @SQL += ' AND pc.Name = @ProductCategory';

    IF @StartDate IS NOT NULL
        SET @SQL += ' AND soh.OrderDate >= @StartDate';

    IF @EndDate IS NOT NULL
        SET @SQL += ' AND soh.OrderDate <= @EndDate';

    SET @Params = '
        @TerritoryName NVARCHAR(100),
        @SalesPersonName NVARCHAR(100),
        @ProductCategory NVARCHAR(100),
        @StartDate DATE,
        @EndDate DATE';

    BEGIN TRY
        EXEC sp_executesql
            @SQL,
            @Params,
            @TerritoryName = @TerritoryName,
            @SalesPersonName = @SalesPersonName,
            @ProductCategory = @ProductCategory,
            @StartDate = @StartDate,
            @EndDate = @EndDate;

        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutionStatus, ParameterValues)
        VALUES ('Reporting.usp_SecureSalesReport', 'Success', @ParameterValues);
    END TRY
    BEGIN CATCH
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutionStatus, ParameterValues)
        VALUES ('Reporting.usp_SecureSalesReport', 'Failed', @ParameterValues);

        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Reporting.usp_VulnerableSalesReport
    @TerritoryName NVARCHAR(100) = NULL,
    @SalesPersonName NVARCHAR(100) = NULL,
    @ProductCategory NVARCHAR(100) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ParameterValues NVARCHAR(MAX);

    SET @ParameterValues =
        CONCAT(
            'TerritoryName=', ISNULL(@TerritoryName, 'NULL'),
            '; SalesPersonName=', ISNULL(@SalesPersonName, 'NULL'),
            '; ProductCategory=', ISNULL(@ProductCategory, 'NULL'),
            '; StartDate=', ISNULL(CONVERT(NVARCHAR(30), @StartDate), 'NULL'),
            '; EndDate=', ISNULL(CONVERT(NVARCHAR(30), @EndDate), 'NULL')
        );

    SET @SQL = '
    SELECT
        st.Name AS TerritoryName,
        CASE 
            WHEN pp.FirstName IS NULL THEN ''No Salesperson''
            ELSE pp.FirstName + '' '' + pp.LastName
        END AS SalesPersonName,
        pc.Name AS ProductCategory,
        soh.OrderDate,
        sod.LineTotal AS TotalSalesAmount,
        sod.OrderQty AS OrderQuantity
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    LEFT JOIN Sales.SalesPerson sp
        ON soh.SalesPersonID = sp.BusinessEntityID
    LEFT JOIN Person.Person pp
        ON sp.BusinessEntityID = pp.BusinessEntityID
    LEFT JOIN Sales.SalesTerritory st
        ON soh.TerritoryID = st.TerritoryID
    JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    LEFT JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
    WHERE 1 = 1';

    IF @TerritoryName IS NOT NULL
        SET @SQL += ' AND st.Name = ''' + @TerritoryName + '''';

    IF @SalesPersonName IS NOT NULL
        SET @SQL += ' AND (pp.FirstName + '' '' + pp.LastName) = ''' + @SalesPersonName + '''';

    IF @ProductCategory IS NOT NULL
        SET @SQL += ' AND pc.Name = ''' + @ProductCategory + '''';

    IF @StartDate IS NOT NULL
        SET @SQL += ' AND soh.OrderDate >= ''' + CONVERT(NVARCHAR(30), @StartDate, 23) + '''';

    IF @EndDate IS NOT NULL
        SET @SQL += ' AND soh.OrderDate <= ''' + CONVERT(NVARCHAR(30), @EndDate, 23) + '''';

    BEGIN TRY
        EXEC(@SQL);

        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutionStatus, ParameterValues)
        VALUES ('Reporting.usp_VulnerableSalesReport', 'Success', @ParameterValues);
    END TRY
    BEGIN CATCH
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutionStatus, ParameterValues)
        VALUES ('Reporting.usp_VulnerableSalesReport', 'Failed', @ParameterValues);

        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER VIEW Reporting.vExecutionSummary
AS
SELECT
    COUNT(*) AS TotalExecutions,
    SUM(CASE WHEN ExecutionStatus = 'Success' THEN 1 ELSE 0 END) AS SuccessfulExecutions,
    SUM(CASE WHEN ExecutionStatus = 'Failed' THEN 1 ELSE 0 END) AS FailedExecutions,
    SUM(CASE WHEN ExecutionStatus = 'Rejected' THEN 1 ELSE 0 END) AS RejectedExecutions
FROM Reporting.ExecutionLog;
GO

SELECT * FROM Reporting.vExecutionSummary;

EXEC Reporting.usp_SecureSalesReport;

EXEC Reporting.usp_SecureSalesReport
    @TerritoryName = 'Northwest';

EXEC Reporting.usp_SecureSalesReport
    @TerritoryName = 'Northwest',
    @ProductCategory = 'Bikes',
    @StartDate = '2013-01-01',
    @EndDate = '2013-12-31';

EXEC Reporting.usp_SecureSalesReport
    @StartDate = '2014-12-31',
    @EndDate = '2014-01-01';

EXEC Reporting.usp_SecureSalesReport
    @TerritoryName = 'Northwest; DROP TABLE Sales.SalesOrderHeader';

EXEC Reporting.usp_VulnerableSalesReport
    @TerritoryName = 'Northwest';

EXEC Reporting.usp_VulnerableSalesReport
    @TerritoryName = 'Northwest'' OR 1=1 --';

SELECT *
FROM Reporting.ExecutionLog
ORDER BY ExecutionTime DESC;

SELECT * 
FROM Reporting.vExecutionSummary;

