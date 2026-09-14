@echo off
cd /d "D:\Programming\FishInsight"
echo Pushing FishInsight to GitHub...
"C:\Program Files\Git\cmd\git.exe" push -u origin main
echo.
echo Done! Please check your GitHub Actions build page.
pause
