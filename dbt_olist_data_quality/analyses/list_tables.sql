select table_name 
from `sunlit-flag-468216-j9.olist_staging.INFORMATION_SCHEMA.TABLES`
where table_type = 'BASE_TABLE'
order by table_name
