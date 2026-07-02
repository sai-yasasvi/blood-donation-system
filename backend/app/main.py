from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.database import Base, engine
import app.models
from app.routers import (
    dashboard, donors, inventory, requests,
    auth, donations, alerts, eligibility,
    camps, supply_chain, allocation
)

Base.metadata.create_all(bind=engine)

app = FastAPI(title="BloodConnect API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"message": "BloodConnect API is running"}


@app.get("/health")
def health():
    return {"status": "ok"}


# Core
app.include_router(dashboard.router,    prefix="/dashboard",    tags=["Dashboard"])
app.include_router(donors.router,       prefix="/donors",       tags=["Donors"])
app.include_router(inventory.router,    prefix="/inventory",    tags=["Inventory"])
app.include_router(requests.router,     prefix="/requests",     tags=["Requests"])
app.include_router(donations.router,    prefix="/donations",    tags=["Donations"])
app.include_router(alerts.router,       prefix="/alerts",       tags=["Alerts"])
app.include_router(auth.router,         prefix="/auth",         tags=["Auth"])

# Extended features
app.include_router(eligibility.router,  prefix="/eligibility",  tags=["Eligibility"])
app.include_router(camps.router,        prefix="/camps",        tags=["Camps"])
app.include_router(supply_chain.router, prefix="/supply-chain", tags=["Supply Chain"])
app.include_router(allocation.router,   prefix="/allocation",   tags=["AI Allocation"])