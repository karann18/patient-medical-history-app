from sqlalchemy import create_engine, Column, Integer, String, JSON
from sqlalchemy.orm import declarative_base, sessionmaker

Base = declarative_base()

class Patient(Base):
    __tablename__ = 'patients'
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    age = Column(Integer, nullable=False)
    gender = Column(String, nullable=False)
    allergies = Column(JSON, nullable=False)
    frequent_problems = Column(JSON, nullable=False)
    medications = Column(JSON, nullable=False)
    surgeries = Column(JSON, nullable=False)
    encounters = Column(JSON, nullable=False)

engine = create_engine('sqlite:///patients.db')
Session = sessionmaker(bind=engine)

def init_db():
    Base.metadata.create_all(engine)
    session = Session()
    if session.query(Patient).count() == 0:
        # Seed the database
        seed_data = [
            Patient(
                id="P-1001", name="John Doe", age=45, gender="Male",
                allergies=["Penicillin", "Nuts"], frequent_problems=["Migraine", "Cold", "Cough"],
                medications=["Aspirin", "Antihistamines"], surgeries=["Appendectomy in 2015"],
                encounters=[
                    {"date": "2025-01-05", "reason": "Follow-up for migraine", "notes": "Prescribed new pain management strategy."},
                    {"date": "2024-08-12", "reason": "Severe cold/cough", "notes": "Advised rest and antihistamines."}
                ]
            ),
            Patient(
                id="P-1002", name="Jane Smith", age=62, gender="Female",
                allergies=["Latex"], frequent_problems=["Hypertension", "Type 2 Diabetes"],
                medications=["Metformin", "Lisinopril"], surgeries=["Knee Replacement (2020)"],
                encounters=[
                    {"date": "2025-02-15", "reason": "Routine checkup", "notes": "Blood pressure elevated. Increased Lisinopril dosage."}
                ]
            ),
            Patient(
                id="P-1003", name="Robert Chen", age=28, gender="Male",
                allergies=["None"], frequent_problems=["Asthma", "Seasonal Allergies"],
                medications=["Albuterol Inhaler", "Cetirizine"], surgeries=["None"],
                encounters=[
                    {"date": "2025-03-10", "reason": "Asthma flare-up", "notes": "Triggered by high pollen."}
                ]
            )
        ]
        session.add_all(seed_data)
        session.commit()
    session.close()

if __name__ == '__main__':
    init_db()
    print("Database initialized.")
