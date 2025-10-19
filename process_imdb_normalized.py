import pandas as pd
import os
import gc

print("--- IMDb Raw Data Normalization Script ---")

                       
INPUT_DIR = '.'                                              
OUTPUT_DIR = '1_data_normalized'

                                 
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)
    print(f"Created output directory: {OUTPUT_DIR}")

                                                                                
                                                 
                                                                                
print("\n[Step 1/3] Processing 'title.basics.tsv' to create 'movies.csv'...")
try:
    basics_df = pd.read_csv(os.path.join(INPUT_DIR, 'title.basics.tsv'), sep='\t', low_memory=False, na_values='\\N')
    
                            
    movies_df = basics_df[basics_df['titleType'] == 'movie'].copy()
    
                
    movies_df.dropna(subset=['startYear'], inplace=True)
    movies_df['startYear'] = pd.to_numeric(movies_df['startYear'], errors='coerce').astype('Int64')
    movies_df.dropna(subset=['startYear'], inplace=True)

                               
    movies_df = movies_df[['tconst', 'primaryTitle', 'startYear']]
    movies_df.rename(columns={'tconst': 'movie_id', 'primaryTitle': 'title', 'startYear': 'year'}, inplace=True)
    
                 
    movies_df.to_csv(os.path.join(OUTPUT_DIR, 'movies.csv'), index=False)
    
                                                                         
    movie_ids_set = set(movies_df['movie_id'])
    
    print(f"-> 'movies.csv' created successfully with {len(movies_df)} movies.")
    del basics_df, movies_df                 
    gc.collect()

except FileNotFoundError:
    print("[ERROR] 'title.basics.tsv' not found. Please place it in the same directory.")
    exit(1)

                                                                                
                                                 
                                                                                
print("\n[Step 2/3] Processing 'name.basics.tsv' to create 'persons.csv'...")
try:
    names_df = pd.read_csv(os.path.join(INPUT_DIR, 'name.basics.tsv'), sep='\t', low_memory=False, na_values='\\N')
    
                
    names_df.dropna(subset=['primaryName'], inplace=True)
    
                               
    persons_df = names_df[['nconst', 'primaryName']]
    persons_df.rename(columns={'nconst': 'person_id', 'primaryName': 'person_name'}, inplace=True)
    
                 
    persons_df.to_csv(os.path.join(OUTPUT_DIR, 'persons.csv'), index=False)

    print(f"-> 'persons.csv' created successfully with {len(persons_df)} people.")
    del names_df, persons_df                 
    gc.collect()

except FileNotFoundError:
    print("[ERROR] 'name.basics.tsv' not found. Please place it in the same directory.")
    exit(1)

                                                                                 
                                                                                    
                                                                                
print("\n[Step 3/3] Processing 'title.principals.tsv' to create linking table...")
try:
    chunk_size = 1_000_000
    principals_reader = pd.read_csv(os.path.join(INPUT_DIR, 'title.principals.tsv'), sep='\t', na_values='\\N', chunksize=chunk_size)
    
    clean_chunks = []
    chunk_count = 0
    for chunk in principals_reader:
        chunk_count += 1
        print(f"  ... processing chunk {chunk_count}")
        
        chunk = chunk[chunk['tconst'].isin(movie_ids_set)]
        chunk = chunk[chunk['category'].isin(['actor', 'actress', 'director'])]
        
        if not chunk.empty:
            clean_chunks.append(chunk)

    print("  ... concatenating clean chunks...")
    principals_df = pd.concat(clean_chunks)
    
    principals_df = principals_df[['tconst', 'nconst', 'category']]
    principals_df.rename(columns={'tconst': 'movie_id', 'nconst': 'person_id'}, inplace=True)
    
                                  
    principals_df.drop_duplicates(inplace=True)
    
    principals_df.to_csv(os.path.join(OUTPUT_DIR, 'movie_principals.csv'), index=False)

    print(f"-> 'movie_principals.csv' created successfully with {len(principals_df)} unique relations.")
    del principals_df, clean_chunks
    gc.collect()

except FileNotFoundError:
    print("[ERROR] 'title.principals.tsv' not found. Please place it in the same directory.")
    exit(1)

print("\n--- Normalization Complete! All files are in the '1_data_normalized' directory. ---")

