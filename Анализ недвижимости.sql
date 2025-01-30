/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Лаптева Диана
 * Дата: 27.10.2024
*/

-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats 
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
    	total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
	),
active_days AS (
    SELECT 
        a.id,
        CASE
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS region,
        CASE
            WHEN a.days_exposition <= 30 THEN 'до месяца'
            WHEN a.days_exposition BETWEEN 31 AND  90 THEN 'до трех месяцев'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
            WHEN a.days_exposition BETWEEN 181 AND 1580 THEN 'более полугода'
            ELSE 'без категории'
        END AS activity_period,
        f.total_area,
        f.rooms,
        f.balcony,
        f.floor,
        a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm
    FROM real_estate.advertisement a
    LEFT JOIN real_estate.flats f USING(id)
    LEFT JOIN real_estate.city c USING(city_id)
    WHERE f.id IN (SELECT id FROM filtered_id)
)
SELECT 
    region,
    activity_period,
    COUNT(id) AS ads_count,
    ROUND((COUNT(id)::NUMERIC / (SELECT COUNT(id) FROM active_days))*100, 2) AS publication_ratio,
    ROUND(AVG(price_per_sqm)::NUMERIC,2) AS avg_price_per_sqm,
    ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor
FROM active_days
GROUP BY region, activity_period
ORDER BY region, activity_period;

-- region               |activity_period|ads_count|publication_ratio|avg_price_per_sqm|avg_total_area|median_rooms|median_balcony|median_floor|
 -----------------------+---------------+---------+-----------------+-----------------+--------------+------------+--------------+------------+
-- Ленинградская область|без категории  |      189|             3.58|         73972.98|         59.08|           2|           1.0|           4|
-- Ленинградская область|более полугода |      482|             9.13|         71346.08|         55.25|           2|           1.0|           4|
-- Ленинградская область|до месяца      |      207|             3.92|         81594.01|         48.43|           1|           1.0|           5|
-- Ленинградская область|до полугода    |      297|             5.62|         74871.98|         53.76|           2|           1.0|           4|
-- Ленинградская область|до трех месяцев|      429|             8.12|         76353.83|         50.97|           2|           1.0|           5|
-- Санкт-Петербург      |без категории  |      401|             7.59|        131233.72|         68.68|           2|           2.0|           7|
-- Санкт-Петербург      |более полугода |     1042|            19.73|        116240.24|         67.38|           2|           1.0|           5|
-- Санкт-Петербург      |до месяца      |      632|            11.97|        112377.61|         55.57|           2|           1.0|           6|
-- Санкт-Петербург      |до полугода    |      702|            13.29|        113997.81|         61.58|           2|           1.0|           6|
-- Санкт-Петербург      |до трех месяцев|      900|            17.04|        113358.53|         58.89|           2|           1.0|           6|

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats f
    LEFT JOIN real_estate.city c USING(city_id)
    LEFT JOIN real_estate.type t USING(type_id)
    LEFT JOIN real_estate.advertisement a USING(id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND t.type = 'город'
    GROUP BY id, first_day_exposition 
    HAVING first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
),
intro AS (
    SELECT 
        a.id,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month,
        EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition * INTERVAL '1 day') AS removal_month,
        a.last_price / f.total_area AS price_per_sqm,
        f.total_area
    FROM real_estate.advertisement a
    LEFT JOIN real_estate.flats f USING(id)
    LEFT JOIN real_estate.city c USING(city_id)
    WHERE a.id IN (SELECT id FROM filtered_id)
),
publication_activity AS (
    SELECT publication_month, 
    	   ROUND(AVG(price_per_sqm)::NUMERIC, 2) AS avg_price_per_sqm,
           ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area,
    	   COUNT(id) AS publication_count,
    	   ROUND(AVG(price_per_sqm)::NUMERIC, 2) AS avg_price_per_sqm_not_removed,
     	   ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area_not_removed
    FROM intro
    GROUP BY publication_month
),
removal_activity AS (
    SELECT removal_month, 
    	   ROUND(AVG(price_per_sqm)::NUMERIC, 2) AS avg_price_per_sqm,
           ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area,
     	   COUNT(id) AS removal_publication,
     	   ROUND(AVG(price_per_sqm)::NUMERIC, 2) AS avg_price_per_sqm_removed,
     	   ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area_removed
    FROM intro
    LEFT JOIN real_estate.advertisement a USING(id)
    WHERE a.days_exposition IS NOT NULL
    GROUP BY removal_month
)
SELECT 
    pa.publication_month AS month,
    pa.publication_count,
    ROUND((pa.publication_count::NUMERIC / (SELECT COUNT(id) FROM intro)) *100, 2) AS publication_ratio,
    ra.removal_publication,
    ROUND((ra.removal_publication::NUMERIC / (SELECT COUNT(id) FROM intro)) *100, 2) AS removal_ratio,
    pa.avg_price_per_sqm,
    ra.avg_price_per_sqm_removed,
    pa.avg_area,
    ra.avg_area_removed, 
    RANK() OVER(ORDER BY publication_count DESC) AS publication_rank,
    RANK() OVER(ORDER BY removal_publication DESC) AS removal_rank
FROM publication_activity pa
LEFT JOIN removal_activity ra ON pa.publication_month = ra.removal_month
ORDER BY publication_month;

-- month|publication_count|publication_ratio|removal_publication|removal_ratio|avg_price_per_sqm|avg_price_per_sqm_removed|avg_area|avg_area_removed|publication_rank|removal_rank|
-- -----+-----------------+-----------------+-------------------+-------------+-----------------+-------------------------+--------+----------------+----------------+------------+
--     1|              207|             5.30|                304|         7.79|        113429.20|                112416.25|   62.83|           61.61|              12|           6|
--     2|              404|            10.35|                252|         6.46|        107644.48|                107711.34|   61.71|           61.69|               1|          10|
--     3|              297|             7.61|                299|         7.66|        101753.22|                107631.72|   61.16|           58.03|              10|           7|
--     4|              315|             8.07|                258|         6.61|        103222.50|                105391.18|   62.39|           59.75|               9|           9|
--     5|              335|             8.59|                203|         5.20|        106822.22|                105882.29|   61.45|           60.49|               6|          12|
--     6|              329|             8.43|                225|         5.77|        106349.45|                103106.37|   61.31|           62.95|               8|          11|
--     7|              333|             8.53|                363|         9.30|        109820.32|                106572.17|   63.01|           62.10|               7|           3|
--     8|              349|             8.94|                360|         9.23|        108889.44|                104919.14|   61.43|           58.71|               5|           4|
--     9|              372|             9.53|                334|         8.56|        111423.44|                106402.75|   59.76|           60.06|               3|           5|
--    10|              350|             8.97|                438|        11.23|        107367.21|                106327.82|   58.70|           60.56|               4|           1|
--    11|              398|            10.20|                421|        10.79|        110211.16|                108616.65|   60.94|           58.97|               2|           2|
--    12|              213|             5.46|                260|         6.66|        108542.38|                108423.22|   61.43|           62.58|              11|           8|

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.city c USING(city_id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND c.city <> 'Санкт-Петербург'
),
removal_ads AS (
    SELECT f.city_id, 
    	   COUNT(a.id) AS sold_count, -- снятые с публикации
    	   AVG(a.days_exposition) AS avg_days_exposition
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    WHERE a.days_exposition IS NOT NULL 
        AND a.id IN (SELECT id FROM filtered_id)
    GROUP BY f.city_id
),
publication AS (
    SELECT 
        f.city_id, 
        COUNT(a.id) AS ads_count, -- по населенным пунктам
        AVG(a.last_price / NULLIF(f.total_area, 0)) AS avg_price_per_sqm,
        AVG(f.total_area) AS avg_total_area
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING(id)
    JOIN real_estate.city c USING(city_id)
    WHERE a.id IN (SELECT id FROM filtered_id)
    GROUP BY f.city_id
),
total_ads AS (
    SELECT COUNT(a.id) AS total_ads_count --всего по ЛенОбл
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    WHERE a.id IN (SELECT id FROM filtered_id)
)
SELECT 
    c.city,
    p.ads_count, 
    ROUND(ra.avg_days_exposition::NUMERIC, 2) AS avg_days_exposition, -- среднее количество дней в продаже (3)
    ROUND((p.ads_count::NUMERIC / t.total_ads_count) * 100,2) AS ads_persentage, -- доля объявлений по городам (в процентах)
    ROUND((ra.sold_count::NUMERIC / t.total_ads_count) * 100,2) AS removal_ratio, -- доля снятых объявлений (2 вопрос)
    ROUND(p.avg_price_per_sqm::NUMERIC, 2) AS avg_price_per_sqm, -- средняя цена за кв.м.
    ROUND(p.avg_total_area::NUMERIC, 2) AS avg_total_area, -- средняя площадь квартиры
    CASE
        WHEN ra.avg_days_exposition < 160 THEN 1
        WHEN ra.avg_days_exposition < 165 THEN 2
        WHEN ra.avg_days_exposition < 185 THEN 3
        ELSE 4
    END AS activity
FROM publication p
JOIN removal_ads ra USING(city_id)
JOIN real_estate.city c USING(city_id)
JOIN total_ads t ON 1=1
WHERE ads_count >= 50
ORDER BY activity, avg_days_exposition;

-- city      |ads_count|avg_days_exposition|ads_persent age|removal_ratio|avg_price_per_sqm|avg_total_area|activity|
   ----------+---------+-------------------+--------------+-------------+-----------------+--------------+--------+
-- Шушары    |      112|             141.75|          6.98|         6.05|         79892.00|         57.28|       1|
-- Мурино    |      147|             157.38|          9.16|         8.54|         87901.45|         45.02|       1|
-- Парголово |       83|             160.49|          5.17|         4.74|         89111.69|         51.52|       2|
-- Колпино   |       54|             164.46|          3.37|         2.99|         76098.35|         56.66|       2|
-- Кудрово   |      136|             167.79|          8.48|         7.86|         97783.87|         46.69|       3|
-- Сестрорецк|       64|             181.42|          3.99|         3.68|        101940.91|         65.15|       3|
-- Всеволожск|      121|             200.05|          7.54|         6.30|         68018.64|         58.28|       4|
-- Пушкин    |       74|             212.85|          4.61|         4.05|        103927.94|         64.07|       4|