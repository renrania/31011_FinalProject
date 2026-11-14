# Ranking Suspicious Bitcoin Transactions (with Review Budget Simulation and Time Analysis)

This project is object to identify top-ranked illicit risk score transactions in a priority queue for compliance analysts to review in a crypto platform with limited compliance review budget. 

## Project Overview

[Briefly introduce the project background.] When high volumns of bitcoin transactions come in, manually reviewing becomes difficult, so a model that identifies higher risk score will help help the review team to review these transactions in the first place. 

This project focuses on [describe the topic or business scenario]a crypto platform with a limited compliance review team. The platform is designed to [describe the main function]. It uses 3 datasets in [dataset name]Elliptic++: txs_features.csv, txs_classes.csv, and txs_edgelist.csv to [describe what will be analyzed or predicted]analyze risk score?.

The project will build an end-to-end cloud-native data pipeline that covers data ingestion, database storage, analytical processing, machine learning, and interactive visualization.

## Business Objective

The main business question is:

> [Write the main business question.]

The project aims to:

- [Objective 1]Produce a reliable metric/threshold, risk score, to estimate the risk of each transaction.
- [Objective 2]Create a reusable engineering pipeline that can be used to estimate risk of most of bitcoin transaction data
- [Objective 3]
- [Objective 4]

The project will evaluate its results using the following metrics:

- [Metric 1]
- [Metric 2]
- [Metric 3]

## Data Sources

**Dataset:** Elliptic++ (txs_features.csv, txs_classes.csv, and txs_edgelist.csv)

**Source:** Elmougy and Liu (2023)

**Download link:** https://github.com/git-disl/EllipticPlusPlus 

The project uses the following files:

| File | Description | Expected Location |
|---|---|---|
| `txs_features.csv` | Transaction ID, time step, 183 features | `data/raw/txs_features.csv` |
| `txs_classes.csv` | Illicit, licit, unknown labels per transaction | `data/raw/txs_classes.csv` |
| `txs_edgelist.csv` | Source Transaction, Target Transaction | `data/raw/txs_edgelist.csv` |

The original data files are not stored in this repository because [explain the reason, such as file size or data-use requirements]. Users must download the files from the original source and place them in the locations listed above.

## Planned Architecture

The planned data flow is:

```text
[Original Data Source]
        |
        v
[Cloud Object Storage]
        |
        v
[Relational Database]
        |
        v
[Analytical Data Warehouse]
        |
        v
[Machine Learning Models]
        |
        v
[Interactive Dashboard]
```

Planned technologies:

| Layer | Technology | Purpose |
|---|---|---|
| Data ingestion | [Technology] | [Purpose] |
| Cloud storage | [Technology] | [Purpose] |
| Relational database | [Technology] | [Purpose] |
| Analytical warehouse | [Technology] | [Purpose] |
| Machine learning | [Technology] | [Purpose] |
| Dashboard | [Technology] | [Purpose] |
| Deployment and testing | [Technology] | [Purpose] |

> This architecture is currently planned and may be adjusted during implementation.

## Repository Structure

```text
[repository-name]/
├── README.md
├── .gitignore
├── .env.example
├── requirements.txt
│
├── data/
│   ├── raw/
│   └── processed/
│
├── src/
│   ├── ingestion/
│   ├── profiling/
│   └── database/
│
├── sql/
│   ├── mysql/
│   └── snowflake/
│
├── notebooks/
├── reports/
├── docs/
├── tests/
├── app/
└── .github/
    └── workflows/
```

Main directories:

- `data/`: [Describe what is stored locally in this directory.]
- `src/ingestion/`: [Describe its purpose.]
- `src/profiling/`: [Describe its purpose.]
- `src/database/`: [Describe its purpose.]
- `sql/`: [Describe its purpose.]
- `notebooks/`: [Describe its purpose.]
- `reports/`: [Describe its purpose.]
- `docs/`: [Describe its purpose.]
- `tests/`: [Describe its purpose.]
- `app/`: [Describe its purpose.]

## Setup

### 1. Clone the repository

```bash
git clone [REPOSITORY_URL]
cd [REPOSITORY_NAME]
```

### 2. Create a Python virtual environment

```bash
python -m venv .venv
```

Activate the environment on macOS or Linux:

```bash
source .venv/bin/activate
```

Activate the environment on Windows:

```bash
.venv\Scripts\activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure environment variables

Copy the example environment file:

```bash
cp .env.example .env
```

Add the required configuration values to `.env`:

```env
GCP_PROJECT_ID=
GCS_BUCKET_NAME=
GOOGLE_APPLICATION_CREDENTIALS=

MYSQL_HOST=
MYSQL_PORT=3306
MYSQL_DATABASE=
MYSQL_USER=
MYSQL_PASSWORD=
```

Do not upload the completed `.env` file or any credentials to GitHub.

### 5. Download the data

1. Download the dataset from [insert download link].
2. Place the three required CSV files in `data/raw/`.
3. Confirm that the filenames match those listed in the Data Sources section.

### 6. Run the ingestion pipeline

```bash
[Insert the command used to run the ingestion pipeline.]
```

> The complete setup and execution instructions will be updated as the pipeline is implemented.

## Roadmap

### Week 1: Data Preparation and Ingestion

- [ ] Set up the GitHub repository
- [ ] Create the initial README
- [ ] Download and profile the source data
- [ ] Build the automated ingestion pipeline
- [ ] Upload raw data to cloud storage
- [ ] Create the relational database and ERD
- [ ] Test repeated ingestion

### Week 2: Data Warehouse and Analysis

- [ ] Create the analytical warehouse
- [ ] Design the analytical schema
- [ ] Write SQL analysis queries
- [ ] Complete exploratory data analysis
- [ ] Prepare the modeling dataset

### Week 3: Machine Learning and Dashboard

- [ ] Train the baseline model
- [ ] Train and compare additional models
- [ ] Generate transaction risk rankings
- [ ] Build the interactive dashboard
- [ ] Add Docker and automated tests

### Week 4: Testing and Final Delivery

- [ ] Test the complete pipeline
- [ ] Verify reproducibility
- [ ] Finalize business findings
- [ ] Complete the presentation
- [ ] Record the final briefing
- [ ] Prepare the final submission package

## Team Members

| Team Member | Responsibilities | Contact |
|---|---|---|
| Qianran Ren | [Responsibilities] | [Contact information] |
| Xitong Xiang | [Responsibilities] | [Contact information] |
| Yuhe Wu | [Responsibilities] | [Contact information] |
