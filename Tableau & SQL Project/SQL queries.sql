Create schema Sqltableauadventureworkproject;
USE Sqltableauadventureworkproject;

/*I . Append/Union of Fact Internet sales and Fact internet sales new - SALES*/

CREATE TABLE Sales AS 
SELECT *, 'FactInternetSales' AS Source
FROM FactInternetSales
UNION ALL
SELECT *, 'Fact_Internet_Sales_New' AS Source
FROM Fact_Internet_Sales_New;

/*II. Merge Products, ProductCategory and ProductSubCategory Tables */

CREATE OR REPLACE VIEW ProductMaster AS
SELECT 
    p.ProductKey,
    p.EnglishProductName,
    p.`Unit price` AS UnitPrice,
    p.StandardCost,
    p.Color,
    p.ProductLine,
    p.DealerPrice,
    p.Class,
    p.Style,
    p.ModelName,
    p.StartDate,
    p.EndDate,
    sub.ProductSubcategoryKey,
    sub.EnglishProductSubcategoryName,
    cat.ProductCategoryKey,
    cat.EnglishProductCategoryName
FROM DimProduct p
LEFT JOIN DimProductSubCategory sub ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN DimProductCategory cat ON sub.ProductCategoryKey = cat.ProductCategoryKey;

/*1. Lookup the Productname from the Product sheet to Sales sheet.*/

CREATE OR REPLACE VIEW Sales_With_Product AS
SELECT 
    s.*, 
    p.EnglishProductName
FROM Sales s
LEFT JOIN ProductMaster p ON s.ProductKey = p.ProductKey;

/* 2. Lookup the Customerfullname from the Customer Table and Unit Price from Product Table to Sales sheet.*/

CREATE OR REPLACE VIEW Sales_With_CustomerProductDetails AS
SELECT 
    s.*, 
    CONCAT(c.FirstName, ' ', c.LastName) AS CustomerFullName
FROM Sales_With_Product s
LEFT JOIN DimCustomer c ON s.CustomerKey = c.CustomerKey;



/*3. Calcuate the following fields from the Orderdatekey field (First Create a Date Field from Orderdatekey)
   A. Year
   B. Monthno
   C. Monthfullname
   D. Quarter(Q1,Q2,Q3,Q4)
   E. YearMonth ( YYYY-MMM)
   F. Weekday Number
   G. Weekday Name
   H. Financial Month (** Financial Year starts from April and ends at March - April : 1, May : 2 ….. March : 12)
   I. Financial Quarter 
*/

CREATE OR REPLACE VIEW Sales_With_DateDetails AS
SELECT
    s.*,
    -- renamed to avoid duplication
    d.FullDateAlternateKey AS OrderDateFormatted,
    d.CalendarYear AS Year,
    d.MonthNumberOfYear AS MonthNo,
    d.EnglishMonthName AS MonthFullName,
    
    -- Quarter
    d.CalendarQuarter AS Quarter,
    
    -- Year-Month
    CONCAT(d.CalendarYear, '-', LEFT(d.EnglishMonthName, 3)) AS YearMonth,

    -- Weekday Number & Name
    d.DayNumberOfWeek AS WeekdayNumber,
    d.EnglishDayNameOfWeek AS WeekdayName,

    -- Financial Month (April = 1 to March = 12)
    CASE 
        WHEN d.MonthNumberOfYear >= 4 THEN d.MonthNumberOfYear - 3
        ELSE d.MonthNumberOfYear + 9
    END AS FinancialMonth,

    -- Financial Quarter
    CASE 
        WHEN d.MonthNumberOfYear BETWEEN 4 AND 6 THEN 'Q1'
        WHEN d.MonthNumberOfYear BETWEEN 7 AND 9 THEN 'Q2'
        WHEN d.MonthNumberOfYear BETWEEN 10 AND 12 THEN 'Q3'
        ELSE 'Q4'
    END AS FinancialQuarter

FROM Sales_With_CustomerProductDetails s
LEFT JOIN DimDate d ON s.OrderDateKey = d.DateKey;


/*Create Sales, Production Cost, and Profit Columns*/

CREATE OR REPLACE VIEW Sales_Final AS
SELECT
    s.*,

    -- Sales Amount
    ROUND(s.UnitPrice * s.OrderQuantity * (1 - s.UnitPriceDiscountPct), 2) AS SalesAmount,

    -- Production Cost
    ROUND(s.ProductStandardCost * s.OrderQuantity, 2) AS ProductionCost,

    -- Profit
    ROUND(
        (s.UnitPrice * s.OrderQuantity * (1 - s.UnitPriceDiscountPct)) - 
        (s.ProductStandardCost * s.OrderQuantity),
        2
    ) AS Profit

FROM Sales_With_DateDetails s;
