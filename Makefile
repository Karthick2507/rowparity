.PHONY: install test qa data tpch-data clean

# Install the framework plus the DuckDB driver (add snowflake/iceberg as needed),
# and activate the pre-commit hook that blocks committing secrets/private keys.
install:
	pip3 install -e ".[test,dev]"
	pre-commit install

# Build the synthetic example warehouse (original 3 cases).
data:
	python3 examples/build_example_data.py

# Build the TPC-H public-dataset warehouse (cases A–G).
tpch-data:
	python3 examples/build_tpch_data.py

# Unit + example tests.
test: install data tpch-data
	pytest -v --junitxml=reports/junit.xml

# Run the declarative YAML cases and write CI reports; non-zero exit on any diff.
qa: install data tpch-data
	mkdir -p reports
	rowparity run examples/cases --json reports/rowparity.json --md reports/rowparity.md

clean:
	rm -rf reports .nox .venv examples/data/*.duckdb examples/data/*.parquet
