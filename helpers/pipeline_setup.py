### Helper script for setting up MATLAB PREP CI environment ###

# Author: Austin Hurst

import os
import shutil
from zipfile import ZipFile
from urllib.request import urlopen
from urllib.error import URLError, HTTPError


# Initialize required directories

download_dir = 'temp'
package_dir = 'deps'
artifact_dir = 'artifacts'

os.mkdir(download_dir)
os.mkdir(package_dir)
os.mkdir(artifact_dir)


# Download test EEG data (curently using S004R04 from the BCI2000 dataset)

eeg_filename = 'S004R04.edf'
eeg_url = 'https://www.physionet.org/files/eegmmidb/1.0.0/S004/{0}?download'

print("* Downloading EEG test data...")
try:
    mod_http = urlopen(eeg_url.format(eeg_filename))
    with open(eeg_filename, 'wb') as out:
        out.write(mod_http.read())
except (URLError, HTTPError):
    raise RuntimeError("Failed to download '{0}'".format(eeg_filename))



# Download and extract EEGLAB and MATLAB PREP

pkgs = {
    'EEGLAB': 'https://sccn.ucsd.edu/eeglab/currentversion/eeglab2021.0.zip',
    'PREP': 'https://github.com/VisLab/EEG-Clean-Tools/archive/refs/heads/master.zip'
}

for name, url in pkgs.items():
    print("* Downloading {0}...".format(name))

    # Download .zip to temporary folder
    download_path = os.path.join(download_dir, '{0}.zip'.format(name))
    try:
        mod_http = urlopen(url)
        with open(download_path, 'wb') as out:
            out.write(mod_http.read())
    except (URLError, HTTPError):
        raise RuntimeError("Failed to download '{0}'".format(url))

    # Unzip downloaded file to MATLAB package directory
    with ZipFile(download_path, 'r') as z:
        z.extractall(package_dir)
        root_dir = z.namelist()[0].split('/')[0]
        outpath = os.path.join(package_dir, root_dir)

    # Rename unzipped package folder to package name for consistency
    pkg_path = os.path.join(package_dir, name)
    shutil.move(outpath, pkg_path)
