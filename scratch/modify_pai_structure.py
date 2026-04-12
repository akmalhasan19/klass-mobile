
import json
import os

def modify_subjects():
    file_path = 'subjects.json'
    
    # Read the data
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    modified_count = 0
    target_subject = 'Pendidikan Agama Islam dan Budi Pekerti'
    target_structure = 'Konsep/Ajaran dasar, Dalil (Al-Qur’an/Hadis), Penjelasan makna, Contoh penerapan, Pembiasaan/praktik, Refleksi/evaluasi diri, dan Latihan/penugasan'
    
    for item in data:
        if item.get('subject') == target_subject:
            item['Structure of content'] = target_structure
            modified_count += 1
            
    # Write the data back
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        
    print(f"Successfully modified {modified_count} entries.")

if __name__ == "__main__":
    modify_subjects()
