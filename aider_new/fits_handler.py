from astropy.io import fits
import numpy as np

def read_fits_file(file_path):
    """
    Reads a FITS file and handles D exponent floating-point numbers.
    """
    with fits.open(file_path) as hdul:
        data = hdul[0].data
        header = hdul[0].header

        # Example: Convert data to a numpy array and handle D exponents
        if data is not None:
            data = np.array(data, dtype=np.float64)

        return data, header
