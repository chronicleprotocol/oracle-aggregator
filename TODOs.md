- Add the function for reading with goodOraclesCounter
- Implement whitelisting of consumer contract (check value for the _bud in current deployment)
- Implement simple tests
- Compare gas costs of different implementations for Median (cmp our function with the one from Aggor)
- Cosmetic improvements in the OracleAggregator contract
- Implement a better low level function for interaction with Chainlink's price feeds under proxy
    - Implement
    - Add tests
- Add much more tests
- Send for the audit


- Ideas
    - No auth: I'd propose to minimise the number of auth'ed operations and to just update the address in the Spark protocol if there will be a need to change the `ageThreshold` param
    - No storage variables: use constants instead
