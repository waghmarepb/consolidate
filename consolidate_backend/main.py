# main.py
from flask import Flask, request, jsonify
from flask_restx import Api, Resource, fields, reqparse
from flask_cors import CORS  # Added CORS import
from werkzeug.datastructures import FileStorage
import pandas as pd
import sqlite3
import os
import logging
from datetime import datetime
import hashlib

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Enable CORS
CORS(app, resources={
    r"/api/*": {
        "origins": ["http://localhost:*", "http://127.0.0.1:*"],
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})

# API configuration
api = Api(
    app,
    version='1.0',
    title='Excel File Processing System',
    description='API for uploading Excel files and managing data',
    doc='/',
    prefix='/api'
)

# Define namespaces
ns_files = api.namespace('files', description='File Operations')
ns_data = api.namespace('data', description='Data Operations')

# Define models
upload_response = api.model('UploadResponse', {
    'message': fields.String(description='Response message'),
    'filename': fields.String(description='Uploaded file name'),
    'rows_processed': fields.Integer(description='Number of rows processed'),
    'preview': fields.Raw(description='Preview of first 5 rows')
})

list_response = api.model('ListResponse', {
    'data': fields.List(fields.Raw, description='List of records'),
    'total': fields.Integer(description='Total number of records'),
    'page': fields.Integer(description='Current page number'),
    'per_page': fields.Integer(description='Items per page'),
    'total_pages': fields.Integer(description='Total number of pages')
})

delete_response = api.model('DeleteResponse', {
    'message': fields.String(description='Success or error message'),
    'records_deleted': fields.Integer(description='Number of records deleted')
})


error_model = api.model('Error', {
    'error': fields.String(description='Error message'),
    'timestamp': fields.DateTime(description='Error timestamp')
})

# File upload parser
file_upload = api.parser()
file_upload.add_argument('file', 
                      location='files',
                      type=FileStorage, 
                      required=True, 
                      help='Excel file (.xls or .xlsx)')

# Configuration
DATABASE = 'excel_data.db'
UPLOAD_FOLDER = 'uploads'

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def init_db():
    """Initialize database with required tables"""
    try:
        with sqlite3.connect(DATABASE) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS excel_data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    srocode TEXT,
                    internaldocumentnumber TEXT,
                    docno TEXT,
                    docname TEXT,
                    registrationdate TEXT,
                    sroname TEXT,
                    micrno TEXT,
                    bank_type TEXT,
                    party_code TEXT,
                    sellerparty TEXT,
                    purchaserparty TEXT,
                    propertydescription TEXT,
                    areaname TEXT,
                    consideration_amt TEXT,
                    marketvalue TEXT,
                    dateofexecution TEXT,
                    stampdutypaid TEXT,
                    registrationfees TEXT,
                    status TEXT,
                    file_name TEXT,
                    upload_date TEXT,
                    data_hash TEXT
                )
            ''')
            
            # Create index for faster duplicate checking
            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_duplicate_check 
                ON excel_data (docno, internaldocumentnumber, registrationdate)
            ''')
            
            logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {str(e)}")
        raise

def calculate_data_hash(df):
    """Calculate unique hash for data content"""
    try:
        key_columns = [
            'docno', 'internaldocumentnumber', 'registrationdate', 
            'sellerparty', 'purchaserparty'
        ]
        data_str = df[key_columns].astype(str).values.tobytes()
        return hashlib.md5(data_str).hexdigest()
    except Exception as e:
        logger.error(f"Error calculating hash: {str(e)}")
        return None

def check_duplicate_data(df, conn):
    """Check if data already exists in database"""
    try:
        cursor = conn.cursor()
        for _, row in df.iterrows():
            query = """
                SELECT file_name 
                FROM excel_data 
                WHERE docno = ? 
                AND internaldocumentnumber = ? 
                AND registrationdate = ? 
                AND sellerparty = ? 
                AND purchaserparty = ?
                LIMIT 1
            """
            params = (
                str(row['docno']).strip(),
                str(row['internaldocumentnumber']).strip(),
                str(row['registrationdate']).strip(),
                str(row['sellerparty']).strip(),
                str(row['purchaserparty']).strip()
            )
            cursor.execute(query, params)
            result = cursor.fetchone()
            if result:
                return True, f"Duplicate data found (previously uploaded in file: {result[0]})"
        return False, ""
    except Exception as e:
        logger.error(f"Error checking duplicates: {str(e)}")
        return False, str(e)

def read_excel_file(file_path):
    """Read Excel file with support for multiple formats"""
    errors = []
    
    # Try reading as UTF-16 HTML
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
            
        if content.startswith(b'\xff\xfe') or content.startswith(b'\xfe\xff'):
            text = content.decode('utf-16')
            dfs = pd.read_html(text)
            if dfs:
                df = dfs[0]
                logger.info("Successfully read file as UTF-16 HTML table")
                return df
    except Exception as e:
        errors.append(f"UTF-16 HTML error: {str(e)}")

    # Try standard read_excel
    try:
        df = pd.read_excel(file_path)
        logger.info("Successfully read file with default engine")
        return df
    except Exception as e:
        errors.append(f"Default engine error: {str(e)}")

    # Try with openpyxl
    try:
        df = pd.read_excel(file_path, engine='openpyxl')
        logger.info("Successfully read file with openpyxl")
        return df
    except Exception as e:
        errors.append(f"openpyxl error: {str(e)}")

    # Try with xlrd
    try:
        df = pd.read_excel(file_path, engine='xlrd')
        logger.info("Successfully read file with xlrd")
        return df
    except Exception as e:
        errors.append(f"xlrd error: {str(e)}")

    raise Exception(f"Failed to read Excel file. Errors: {'; '.join(errors)}")

@ns_files.route('/upload')
class UploadExcel(Resource):
    @api.expect(file_upload)
    @api.response(200, 'Success', upload_response)
    @api.response(400, 'Invalid file', error_model)
    @api.response(500, 'Server error', error_model)
    def post(self):
        """Upload and process Excel file"""
        try:
            args = file_upload.parse_args()
            file = args['file']
            
            if not file:
                return {'error': 'No file provided'}, 400

            if not file.filename.endswith(('.xls', '.xlsx')):
                return {'error': 'Invalid file type. Only .xls and .xlsx files are allowed'}, 400

            # Generate unique filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{timestamp}_{file.filename}"
            filepath = os.path.join(UPLOAD_FOLDER, filename)

            # Save file temporarily
            try:
                file.save(filepath)
                logger.info(f"File saved: {filepath}")
            except Exception as e:
                logger.error(f"Error saving file: {str(e)}")
                return {'error': f'Error saving file: {str(e)}'}, 500

            try:
                # Read file
                df = read_excel_file(filepath)
                
                if df is None or df.empty:
                    raise Exception("File is empty or could not be read")

                # Clean column names
                df.columns = df.columns.str.strip().str.lower()
                
                # Verify required columns
                required_columns = [
                    'srocode', 'internaldocumentnumber', 'docno', 'docname',
                    'registrationdate', 'sroname', 'micrno', 'bank_type',
                    'party_code', 'sellerparty', 'purchaserparty', 'propertydescription',
                    'areaname', 'consideration_amt', 'marketvalue', 'dateofexecution',
                    'stampdutypaid', 'registrationfees', 'status'
                ]
                
                missing_columns = [col for col in required_columns if col not in df.columns]
                if missing_columns:
                    raise Exception(f"Missing required columns: {', '.join(missing_columns)}")

                # Check for duplicates
                with sqlite3.connect(DATABASE) as conn:
                    is_duplicate, duplicate_message = check_duplicate_data(df, conn)
                    if is_duplicate:
                        raise Exception(duplicate_message)
                
                # Process data
                df = df.fillna('')
                df['file_name'] = filename
                df['upload_date'] = datetime.now().isoformat()
                df['data_hash'] = calculate_data_hash(df)
                
                # Convert all columns to string
                for column in df.columns:
                    df[column] = df[column].astype(str).str.strip()

                # Save to database
                with sqlite3.connect(DATABASE) as conn:
                    df.to_sql('excel_data', conn, if_exists='append', index=False)
                    logger.info("Data saved to database")

                return {
                    'message': 'File uploaded and processed successfully',
                    'filename': filename,
                    'rows_processed': len(df),
                    'preview': df.head(5).to_dict('records')
                }

            except Exception as e:
                logger.error(f"Error processing file: {str(e)}")
                return {'error': str(e)}, 500
            finally:
                # Clean up temporary file
                if os.path.exists(filepath):
                    os.remove(filepath)

        except Exception as e:
            logger.error(f"Upload error: {str(e)}")
            return {'error': str(e)}, 500

@ns_data.route('/list')
class ListData(Resource):
    @api.doc(params={
        'page': 'Page number',
        'per_page': 'Items per page',
        'sort_by': 'Column to sort by',
        'order': 'Sort order (asc/desc)'
    })
    @api.response(200, 'Success', list_response)
    def get(self):
        """Get list of all records"""
        try:
            page = request.args.get('page', 1, type=int)
            per_page = request.args.get('per_page', 10, type=int)
            sort_by = request.args.get('sort_by', 'upload_date')
            order = request.args.get('order', 'desc').upper()

            offset = (page - 1) * per_page

            with sqlite3.connect(DATABASE) as conn:
                cursor = conn.cursor()
                
                # Get total count
                cursor.execute('SELECT COUNT(*) FROM excel_data')
                total = cursor.fetchone()[0]

                # Get paginated data
                query = f'SELECT * FROM excel_data ORDER BY {sort_by} {order} LIMIT ? OFFSET ?'
                cursor.execute(query, (per_page, offset))
                
                columns = [description[0] for description in cursor.description]
                results = []
                
                # Process results
                for row in cursor.fetchall():
                    record = dict(zip(columns, row))
                    # Format dates
                    for date_field in ['registrationdate', 'dateofexecution', 'upload_date']:
                        if record.get(date_field):
                            try:
                                date_obj = datetime.strptime(record[date_field], '%Y-%m-%d')
                                record[date_field] = date_obj.strftime('%Y-%m-%d')
                            except:
                                pass
                    # Format numbers
                    for num_field in ['consideration_amt', 'marketvalue', 'stampdutypaid', 'registrationfees']:
                        if record.get(num_field):
                            try:
                                record[num_field] = "{:,.2f}".format(float(record[num_field]))
                            except:
                                pass
                    results.append(record)

                return {
                    'data': results,
                    'total': total,
                    'page': page,
                    'per_page': per_page,
                    'total_pages': (total + per_page - 1) // per_page
                }

        except Exception as e:
            logger.error(f"Error fetching data: {str(e)}")
            return {'error': f'Error fetching data: {str(e)}'}, 500

# Update the delete endpoint with proper Swagger documentation
@ns_data.route('/delete-all')
class DeleteAllData(Resource):
    @api.doc(description='Delete all records from the database')
    @api.response(200, 'Success', delete_response)
    @api.response(500, 'Server error', error_model)
    def delete(self):
        """Delete all records from the database"""
        try:
            with sqlite3.connect(DATABASE) as conn:
                cursor = conn.cursor()
                
                # Get the count of records before deletion
                cursor.execute('SELECT COUNT(*) FROM excel_data')
                records_count = cursor.fetchone()[0]
                
                # Delete all records
                cursor.execute('DELETE FROM excel_data')
                
                # Reset the auto-increment counter
                cursor.execute('DELETE FROM sqlite_sequence WHERE name="excel_data"')
                
                logger.info(f"Deleted {records_count} records from database")
                
                return {
                    'message': 'All records deleted successfully',
                    'records_deleted': records_count
                }

        except Exception as e:
            logger.error(f"Error deleting data: {str(e)}")
            return {'error': f'Error deleting data: {str(e)}'}, 500
if __name__ == '__main__':
    try:
        init_db()
        print("\nSwagger UI available at http://127.0.0.1:5000/")
        print("\nAPI Documentation:")
        print("  - POST /api/files/upload    (Upload Excel file)")
        print("  - GET  /api/data/list      (List all data)")
        print("  - DELETE /api/data/delete-all (Delete all records)")
        # Run the app with CORS support
        app.run(host='127.0.0.1', port=5000, debug=True)
    except Exception as e:
        logger.error(f"Server startup error: {str(e)}")
        print(f"\nError starting server: {str(e)}")
        input("\nPress Enter to exit...")