#!/bin/bash
if [ -f "./antenv/bin/activate" ]; then
    source ./antenv/bin/activate
elif [ -f "../antenv/bin/activate" ]; then
    source ../antenv/bin/activate
fi

# In case opencv-python GUI was installed, uninstall it so headless cv2 is strictly used
pip uninstall -y opencv-python > /dev/null 2>&1 || true

cd backend
echo "Running database migrations..."
python manage.py migrate
echo "Seeding database..."
python seed.py
echo "Starting Gunicorn server..."
gunicorn attend_backend.wsgi:application --bind=0.0.0.0:8000 --timeout 600

