-- Set the role context
USE ROLE SYSADMIN;

-- Create the necessary objects
CREATE WAREHOUSE XS_WH WAREHOUSE_SIZE=XSMALL INITIALLY_SUSPENDED=TRUE AUTO_SUSPEND=60 COMMENT = 'XSMALL Warehouse';
CREATE DATABASE EA COMMENT = 'External Access Example DB';
CREATE SCHEMA NHL COMMENT = 'NHL API';

-- Set the worksheet context
USE WAREHOUSE XS_WH;
USE DATABASE EA;
USE SCHEMA NHL;

-- Create a network rule
CREATE NETWORK RULE IF NOT EXISTS nhl_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('api-web.nhle.com');

-- Create one or more secrets
-- Note: Since this is a freely accessible API, no secret objects need to be created

-- Switch role context
USE ROLE ACCOUNTADMIN;

-- Create an external access integration
CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS nhl_access_integration
    ALLOWED_NETWORK_RULES = (nhl_network_rule)
    ENABLED = true;

-- Grant access on integration to SYSADMIN role
GRANT USAGE ON INTEGRATION nhl_access_integration TO ROLE SYSADMIN;

-- Switch role context
USE ROLE SYSADMIN;

-- Create a UDF object that calls the NHL API
CREATE FUNCTION IF NOT EXISTS call_nhl_api(URL STRING)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = 3.10
HANDLER = 'call_nhl_api'
EXTERNAL_ACCESS_INTEGRATIONS = (nhl_access_integration)
PACKAGES = ('requests')
AS
$$
import _snowflake
import requests
import json

def call_nhl_api(url):

    url = f"{url}"

    response = requests.get(url)

    response_json = response.json()

    if (response.ok):
        return response_json
    else:
        status = response.raise_for_status()
        return status
$$;

-- Call the NHL API
SELECT call_nhl_api('https://api-web.nhle.com/v1/schedule/now');
SELECT call_nhl_api('https://api-web.nhle.com/v1/standings/now');
SELECT call_nhl_api('https://api-web.nhle.com/v1/roster-season/COL');
