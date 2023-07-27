# Authorization Performance Experiments

## PostgreSQL

### Start PostgreSQL
```
cd postgres
docker-compose -f postgres/docker-compose.yml up
```

### Load data in postgres database
```
psql postgresql://postgres:postgrespassword@localhost:5433/postgres < Chinook_PostgreSql.sql
```

### Connect to postgres database
```
psql postgresql://postgres:postgrespassword@localhost:5433/postgres
```

### Insert dummy data in Track table to get rows count to 10M
```
INSERT INTO "Track"("TrackId", "Name", "AlbumId", "MediaTypeId", "GenreId", "Milliseconds", "Bytes", "UnitPrice")
SELECT i::int, i::text, 1, 1, 1, 276349, 9056902, 0.99
FROM generate_series(3504, 10000000) AS t(i);
```

### Setup role and policies
```
create role "User";

grant select on "Album" to "User";

CREATE POLICY album_rls_policy ON "Album" FOR SELECT TO public USING ("ArtistId"=((current_setting('rls.artistID'))::integer));

ALTER TABLE "Album" ENABLE ROW LEVEL SECURITY;

grant select on "Track" to "User";

CREATE POLICY track_rls_policy ON "Track" FOR SELECT to public
USING (
  EXISTS (
    select 1 from "Album" where "Track"."AlbumId" = "Album"."AlbumId"
  )
);

ALTER TABLE "Track" ENABLE ROW LEVEL SECURITY;
```

### Query and verify the policies through psql
```
set role "User";
set rls.artistID = '116';
select * from "Track";
```

### Explain analyze
```
explain analyze select * from "Track";
```

### Query plan

```
                                                             QUERY PLAN                                                              
-------------------------------------------------------------------------------------------------------------------------------------
 Seq Scan on "Track"  (cost=0.00..81944263.95 rows=5000048 width=61) (actual time=46.275..500.955 rows=14 loops=1)
   Filter: (hashed SubPlan 2)
   Rows Removed by Filter: 9999986
   SubPlan 2
     ->  Index Scan using "IFK_AlbumArtistId" on "Album"  (cost=0.15..8.17 rows=1 width=4) (actual time=0.031..0.032 rows=1 loops=1)
           Index Cond: ("ArtistId" = (current_setting('rls.artistID'::text))::integer)
 Planning Time: 0.211 ms
 JIT:
   Functions: 17
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.496 ms, Inlining 9.673 ms, Optimization 22.392 ms, Emission 13.851 ms, Total 46.412 ms
 Execution Time: 501.512 ms
(12 rows)
```

### Query and benchmark performance through pgbench
Refer https://www.postgresql.org/docs/current/pgbench.html

```
pgbench -h localhost -p 5433 -U postgres postgres -f postgres/benchmark_script.sql -c 100 -j 10
```

where
c is number of concurrent database clients (default: 1)
and
j is number of threads (default: 1)

## Hasura GraphQL Engine

### Start Engine
```
cd hasura
docker-compose -f hasura/docker-compose.yml up
```

### Load data in postgres database
```
psql postgresql://postgres:postgrespassword@localhost:5432/postgres < Chinook_PostgreSql.sql
```

### Connect to postgres database
```
psql postgresql://postgres:postgrespassword@localhost:5432/postgres
```

### Insert dummy data in Track table to get rows count to 10M
```
INSERT INTO "Track"("TrackId", "Name", "AlbumId", "MediaTypeId", "GenreId", "Milliseconds", "Bytes", "UnitPrice")
SELECT i::int, i::text, 1, 1, 1, 276349, 9056902, 0.99
FROM generate_series(3504, 10000000) AS t(i);
```

### Connect database in Console
- Open http://localhost:8080/console in a web brower.

- In Data tab, click on `Connect Database`.

![Connect Database](screenshots/connect-database.png)

- Select `Postgres` and click on `Connect Existing Database`.

![Connect Existing Postgres Database](screenshots/connect-existing-postgres-database.png)

- Enter connection details and click on `Connect Database`.

![Connection Details](screenshots/connection-details.png)

- Expand `Chinook` and click on `Public`. Click on `Track All` to track all tables.

![Track Tables](screenshots/track-tables.png)

- Click on `Track All` to track all foreign-key relationships.

![Track Foreign Key Relationships](screenshots/track-foreign-key-relationships.png)

### Setup role and policies
- Click on `Album` and configure permissions for `user` role . Click on `Save Permissions`.

![User Role in Album](screenshots/user-role-in-album.png)

- Click on `Track` and configure permissions for `user` role . Click on `Save Permissions`.

![User Role in Track](screenshots/user-role-in-track.png)

### Query and verify the policies through GraphiQL

![Query](screenshots/query.png)

### Generated SQL
Click on `Analyze` to view `Generated SQL`.

![Analyze](screenshots/analyze.png)

### Analyze
`EXPLAIN ANALYZE` the `Generated SQL` in psql.

### Query Plan
```
                                                                QUERY PLAN                                                                 
-------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=16.42..16.43 rows=1 width=32) (actual time=0.397..0.398 rows=1 loops=1)
   ->  Nested Loop  (cost=0.28..16.27 rows=10 width=71) (actual time=0.171..0.209 rows=14 loops=1)
         ->  Seq Scan on "Album" "__be_0_Album"  (cost=0.00..7.34 rows=1 width=4) (actual time=0.105..0.137 rows=1 loops=1)
               Filter: ("ArtistId" = 116)
               Rows Removed by Filter: 346
         ->  Index Scan using "IFK_TrackAlbumId" on "Track"  (cost=0.28..8.83 rows=10 width=71) (actual time=0.061..0.064 rows=14 loops=1)
               Index Cond: ("AlbumId" = "__be_0_Album"."AlbumId")
   SubPlan 1
     ->  Result  (cost=0.00..0.01 rows=1 width=32) (actual time=0.002..0.002 rows=1 loops=14)
 Planning Time: 1.937 ms
 Execution Time: 0.542 ms
(11 rows)
```

### Query and benchmark performance through pgbench
Save the `Generated SQL` in a `.sql` file.

```
pgbench -h localhost -p 5432 -U postgres postgres -f <file-name>.sql -c 100 -j 10
```

where
c is number of concurrent database clients (default: 1)
and
j is number of threads (default: 1)

### Query and benchmark GraphQL API performance through graphql-bench
Refer https://github.com/hasura/graphql-bench

Follow the setup instructions.

In `graphql-bench/app/cli/bin` directory:

Update config
```
url: 'http://localhost:8080/v1/graphql'
headers:
    X-Hasura-Role: user
    X-Hasura-Artist-Id: 116
# "Debug" mode enables request and response logging for Autocannon and K6
# This lets you see what is happening and confirm proper behavior.
# This should be disabled for genuine benchmarks, and only used for debugging/visibility.
debug: false
queries:
    # Name: Unique name for the query
  - name: SearchTracksWithArtist
    # Tools: List of benchmarking tools to run: ['autocannon', 'k6', 'wrk2']
    tools: [autocannon, k6]
    # Execution Strategy: the type of the benchmark to run. Options are:
    # REQUESTS_PER_SECOND: Fixed duration, fixed rps. Example parameters:
    #   duration: 10s
    #   rps: 500
    # FIXED_REQUEST_NUMBER: Complete requests as fast as possible, no duration. Example parameters:
    #   requests: 10000
    # MAX_REQUESTS_IN_DURATION: Make as many requests as possible in duration. Example parameters:
    #   duration: 10s
    # MULTI_STAGE: (K6 only currently) Several stages of REQUESTS_PER_SECOND benchmark. Example parameters:
    #   initial_rps: 0
    #   stages:
    #     - duration: 5s
    #       target: 100
    #     - duration: 10s
    #       target: 1000
    # CUSTOM: Pass completely custom options to each tool (see full API spec for all supported options, very large)
    execution_strategy: REQUESTS_PER_SECOND
    rps: 100
    duration: 1s
    connections: 10
    query: |
      query SearchTracksWithArtist {
        Track {
          AlbumId
          Bytes
          Composer
          GenreId
          MediaTypeId
          Milliseconds
          Name
          TrackId
          UnitPrice
        }
      }
```

Run:
```
./run query -c config.yaml
```

## Conclusion

Query execution with Hasura's Authorization (`Execution Time: 0.542 ms`) performs considerably better than that on PostgreSQL RLS enabled tables (`Execution Time: 501.512 ms`).