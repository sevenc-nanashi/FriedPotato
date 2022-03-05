@echo off
cd bg_gen_python
python -m venv .venv
call .venv\Scripts\activate
pip install -r requirements.txt
