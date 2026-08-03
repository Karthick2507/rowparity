"""Nox entrypoints — runnable from any CI system (Jenkins, GitLab, cron, laptop).

    nox -s tests     # run the unit + example test suite
    nox -s qa        # run the YAML cases, write reports/, non-zero on any diff
"""
import nox

nox.options.reuse_existing_virtualenvs = True


@nox.session
def tests(session):
    session.install("-e", ".[test]")
    session.run("pytest", "-v", "--junitxml=reports/junit.xml", *session.posargs)


@nox.session
def qa(session):
    """Run declarative data-QA cases and publish reports."""
    session.install("-e", ".[duckdb,dbt]")     # add ,snowflake,iceberg for those sources
    cases = session.posargs[0] if session.posargs else "examples/cases"
    session.run("python", "examples/build_example_data.py")   # runs a real dbt-duckdb build for Case 01
    session.run("python", "examples/build_tpch_data.py")
    session.run(
        "rowparity", "run", cases,
        "--json", "reports/rowparity.json",
        "--md", "reports/rowparity.md",
    )
