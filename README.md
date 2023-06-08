# Doppler Effect Simulator


## The Doppler Effect

The Doppler Effect or Doppler Shift is the apparent change in the frequency of a wave (e.g., sound waves or light waves) as perceived by an observer moving relative to the wave source. When the source is moving towards the observer, the wavelengths appear shorter, resulting in a higher perceived pitch for sound waves or a shift towards the blue end of the spectrum for light waves (blueshift). Conversely, when the source is moving away from the observer, the wavelengths appear longer, resulting in a lower perceived pitch for sound waves or a shift towards the red end of the spectrum for light waves (redshift). 

In general, if the speeds of both the source and the observer relative to the medium are lower than the speed of waves in the medium, we can write: 

$$
f =  \left (\frac{c \pm v_o}{c \pm v_s} \right ) \cdot f_0
$$

where:

- $f$ is the observed frequency  
- $f_0$ is the source's emitted frequency  
- $c$ is the propagation speed of the wave in the medium  
- $v_o$ is the speed of the observer relative to the medium  
- $v_s$ is the speed of the source relative to the medium  

Considering an observer stationary relative to the medium ($v_o=0$), we can write:

$$
f =  \left (\frac{c}{c \pm v_s} \right ) \cdot f_0
$$

The latter is the the case we are interested in, as it is the one demonstrated in the current version of the simulator.
