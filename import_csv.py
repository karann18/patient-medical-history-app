import csv
from models import Session, Patient

def run():
    session = Session()
    
    # Delete existing data
    session.query(Patient).delete()
    
    with open(r'C:\Users\karan\Downloads\MOCK_DATA.csv', mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Map columns properly based on CSV header
            # id,name,age,gender,allergies,frequent_problems,medications,surgeries,encountes
            
            p = Patient(
                id=f"P-{row['id']}",
                name=row['name'],
                age=int(row['age']),
                gender=row['gender'],
                allergies=[row['allergies']] if row['allergies'] else ["None"],
                frequent_problems=[row['frequent_problems']] if row['frequent_problems'] else ["None"],
                medications=[row['medications']] if row['medications'] else ["None"],
                surgeries=[row['surgeries']] if row['surgeries'] else ["None"],
                encounters=[{
                    "date": "2025-05-29",
                    "reason": row['encountes'],
                    "notes": "Imported from Mock Data"
                }] if row.get('encountes') else []
            )
            session.add(p)
    
    session.commit()
    session.close()
    print("Successfully replaced patient data with MOCK_DATA.csv")

if __name__ == '__main__':
    run()
