#!/bin/bash
# Create Blue Team Analyst User

if id "analyst" &>/dev/null; then
    echo "User analyst already exists."
else
    useradd -m -s /bin/bash analyst
    echo 'analyst:blue_team_rocks' | chpasswd
    echo "User analyst created successfully."
fi
