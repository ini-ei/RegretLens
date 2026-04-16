import sys
import os
DIR=os.path.dirname(__file__)
sys.path.append(DIR)
sys.path.insert(0, '/home/s2322007/myapp/')
from app import app as application
