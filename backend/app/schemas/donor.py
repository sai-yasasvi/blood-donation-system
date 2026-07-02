from pydantic import BaseModel

class DonorBase(BaseModel):
    user_id: int
    blood_type: str
    is_eligible: bool = True

class DonorCreate(DonorBase):
    pass

class DonorResponse(DonorBase):
    donor_id: int
    total_donations: int

    class Config:
        from_attributes = True