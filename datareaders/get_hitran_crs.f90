! Comments from Kelly's original code
! read logicals and parameters controlling calculations
!
! molnum is the hitran molecule number.
!
! start, step, and npoints define the calculation grid. in order to avoid
! undersampling the grid should be at least as fine as 1/3 of the smallest
! gaussian fwhm of a spectral line, or 0.5550 times the smallest gaussian hw1e.
! this insures that the maximum sampling error is <1.24e-4 of the full-scale
! line-shape. later: add automatic check for undersampling wrt voigt widths
!
! press is the pressure in atmospheres (millibars / 1013.25). temp is the
! temperature in degrees kelvin.
!
! nvoigt is the number of grid points to each side of a spectral line for
! performing the voigt calculation. assuming calculation to <= 1e-4 is desired,
! nvoigt should be the greater of (1) 100 * hwhm_max / step, where hwhm_max is
! the largest lorentzian hwhm of a line and step is the grid spacing;
! (2) 3.035 * hw1e_max / step, where hw1e_max is the largest gaussian hw1e of a
! line.
!
! hw1e is the gaussian slit with at 1/e intensity. hw1e = the full width at
! half-maximum, fwhm, * 0.60056 = fwhm / (2 * sqrt (ln 2)).
!
! nmod gives the option not to write out humongous spectral files by printing
! every nmod^th spectral value

! Notes: 
! 1. Qpower needs to be more accurate (now updated)
! 2. pressure-induced shift is not considered (now shifted)
! 3. Intensity for different isotopes is weighted by their fraction in the atmosphere
! 4. Is nvoigt enough?
! 5. Need to speed up Voigt calculations? (use humilik procedure to speed up calculation)
! 6. Sinc function?

! Updates
! Feb. 2012: add HUMLIK function, which improves the calculation by a factor of 5 compared to voigt
! Feb. 25, 2012: add crsdt
! Aug. 27, 2012: Update Kelly's new partition function
! April 13, 2015: 
!    a. Update to HITRAN 2012 (additional O2 delta bands with intensity correction
!    b. Convolve from very high resolution to input grid by slit function with solar I0 effect correction
!    c. Perform line by line calculation only for spectral regions with lines


SUBROUTINE get_hitran_crs(the_molecule, nlambda, lambda, ni0, i0wave, hi0, &
     is_wavenum, is_fwhm_inlam, nz, ps, ts, fwhm, scale, crs, errstat, crsdt)

IMPLICIT none

! Input/output parameters
INTEGER, INTENT(IN)                                :: nlambda, nz, ni0
CHARACTER (LEN=6), INTENT(IN)                      :: the_molecule
LOGICAL, INTENT (IN)                               :: is_wavenum       ! *** T: wavenumber, F: nm ***
LOGICAL, INTENT (IN)                               :: is_fwhm_inlam    ! is unit for fwhm in nm?
REAL(KIND=8), INTENT(IN)                           :: fwhm             ! *** in cm^-1 or nm ***
REAL(KIND=8), INTENT(IN)                           :: scale            
REAL(KIND=8), DIMENSION(nlambda), INTENT(IN)       :: lambda
REAL(KIND=8), DIMENSION(ni0), INTENT(IN)           :: i0wave, hi0
REAL(KIND=8), DIMENSION(nz), INTENT(IN)            :: ps, ts
INTEGER, INTENT(OUT)                               :: errstat
REAL(KIND=8), DIMENSION(nlambda, nz), INTENT(OUT)  :: crs
REAL(KIND=8), DIMENSION(nlambda, nz), INTENT(OUT), OPTIONAL :: crsdt


INTEGER, PARAMETER :: maxlines  = 40000        ! spectral lines
INTEGER, PARAMETER :: maxmols   = 42           ! number of molecules in hitran
INTEGER, PARAMETER :: maxiso    = 8            ! maximum # of isotopes
INTEGER, PARAMETER :: maxpoints = 800001       ! number of points in spectrum
CHARACTER (LEN=6), DIMENSION(maxmols), PARAMETER :: molnames = (/ &
     'H2O   ', 'CO2   ', 'O3    ', 'N2O   ', 'CO    ', 'CH4   ', 'O2    ', &
     'NO    ', 'SO2   ', 'NO2   ', 'NH3   ', 'HNO3  ', 'OH    ', 'HF    ', &
     'HCL   ', 'HBR   ', 'HI    ', 'CLO   ', 'OCS   ', 'H2CO  ', 'HOCL  ', &
     'N2    ', 'HCN   ', 'CH3CL ', 'H2O2  ', 'C2H2  ', 'C2H6  ', 'PH3   ', &
     'COF2  ', 'SF6   ', 'H2S   ', 'HCOOH ', 'HO2   ', 'O     ', 'CLONO2', &
     'NO+   ', 'HOBR  ', 'C2H4  ', 'CH3OH ', 'CH3BR ', 'CH3CN ', '   CF4'/)

! constants
REAL(KIND=8), PARAMETER :: pi = 3.14159265358979d0
REAL(KIND=8), PARAMETER :: c = 2.99792458d10
REAL(KIND=8), PARAMETER :: p0 = 1013.25d0
REAL(KIND=8), PARAMETER :: t0 = 296.d0          ! hitran standard
! codata 2002 constants
REAL(KIND=8), PARAMETER :: h = 6.6260693d-27
REAL(KIND=8), PARAMETER :: an = 6.0221415d23
REAL(KIND=8), PARAMETER :: r = 82.057463d0      ! derived
REAL(KIND=8), PARAMETER :: rk = 1.3806505d-16
REAL(KIND=8), PARAMETER :: du = 2.6867773d16    ! derived
REAL(KIND=8), PARAMETER :: c2 = 1.4387752d0

INTEGER, DIMENSION(maxlines)             :: mol, iso
REAL(KIND=8), DIMENSION(maxlines)        :: sigma0, strnth, einstein, alpha, &
     elow, coeff, selfbrdn, pshift
REAL(KIND=8), DIMENSION(maxmols, maxiso) :: q296, q
LOGICAL, DIMENSION(maxmols, maxiso)      :: if_q
REAL(KIND=8), DIMENSION(maxpoints)       :: pos, spec,  voigtx, v, posnm, hi0new, hi0new1
REAL(KIND=8), DIMENSION(nlambda)         :: wavenum
CHARACTER(LEN=132)                       :: hitran_filename

INTEGER          :: molnum, npoints, nvoigt, ntemp, niter, iter
REAL(KIND=8)     :: wstart, wend, step, press, temp, minline_vg, &
     minslit_fwhm, min_fwhm, maxline_vg, maxline_hwhm, voigt_extra

INTEGER          :: i, mol_temp, iso_temp, nlines, nvlo, nvhi, idx, MEND, iz
REAL(KIND=8)     :: sigma0_temp, strnth_temp, einstein_temp, alpha_temp, &
     selfbrdn_temp, elow_temp, coeff_temp, pshift_temp, sigma_temp
REAL(KIND=8)     :: vg, voigta, ratio1, ratio2, ratio, vnorm, rt0t, rc2t, rc2t0
CHARACTER(LEN=2) :: molc
CHARACTER(LEN=6) :: the_moleculeU
LOGICAL          :: write_diagnostics = .false.
LOGICAL          :: use_humlik = .true.

REAL (KIND=8), DIMENSION(maxmols, maxiso, 148:342), SAVE :: q_input  
REAL(KIND=8), DIMENSION(maxmols, maxiso),           SAVE :: amu
LOGICAL,                                            SAVE :: first_qload = .TRUE.

INTEGER,          EXTERNAL :: ibin
CHARACTER (LEN=6),     EXTERNAL :: StrUpCase

! Initialize error status
errstat = 0

! Determine which molecule and database file
the_moleculeU = the_molecule !StrUpCase(the_molecule)
molnum = 0
DO i = 1, maxmols
   !IF (LGE(the_moleculeU, molnames(i)) .AND. LLE(the_moleculeU, molnames(i))) THEN 
   IF (TRIM(the_moleculeU) == TRIM(molnames(i)) ) THEN 
      molnum = i; EXIT
   ENDIF
ENDDO
IF (molnum == 0) THEN
   WRITE(*, *) 'This molecule ', the_molecule, ' is not found in HITRAN!!!'
   errstat = 1; RETURN
ENDIF

IF (is_wavenum) THEN
   wstart = lambda(1); wend = lambda(nlambda)
ELSE
   wstart = 1.0D7/lambda(nlambda); wend = 1.0D7/lambda(1)
ENDIF
IF (write_diagnostics) WRITE(*, *) 'wstart = ', wstart, ' wend = ', wend

WRITE(molc, '(I2.2)') molnum
!xliu, 04/06/2015, Update to the latest version of HITRAN 2012
hitran_filename = '../geocape_data/HITRAN/' // molc // '_hit12.par'
IF (molnum == 4 .OR. molnum == 8 .OR. molnum == 23 .OR. molnum == 25 .OR. molnum == 30 &
     .OR. molnum == 32 .OR. molnum == 34 .OR. molnum == 35 .OR. molnum == 38           &
     .OR. molnum == 39 .OR. molnum == 40 .OR. molnum == 41 .OR. molnum == 42) THEN
   hitran_filename = '../geocape_data/HITRAN/' // molc // '_hit08.par'
ENDIF
IF (molnum == 7) THEN  ! Add new delta bands ~ 580 nm, but need to reduce intensity by ~1.8
   hitran_filename = '../geocape_data/HITRAN/' // molc // '_hit12-withnewband.par'
ENDIF

! setup hitrans
!xliu, 004/06/2015, load amu once and move q_load here from below
IF (first_qload) THEN
   CALL hitran_setup (maxmols, maxiso, amu)
   CALL q_load (maxmols, maxiso, q_input)
   first_qload = .FALSE.
ENDIF

IF (write_diagnostics) WRITE(*, *) TRIM(ADJUSTL(hitran_filename))
OPEN(unit = 22, file = hitran_filename, status = 'old')

! read lines (15 cm^-1 extra on both sides)
i = 1
DO 
   READ (22, '(i2, i1, f12.6, 2e10.3, 2f5.4, f10.4, f4.2, f8.6)', IOSTAT = MEND) mol_temp, &
        iso_temp, sigma0_temp, strnth_temp, einstein_temp, alpha_temp, selfbrdn_temp, &
        elow_temp, coeff_temp, pshift_temp
   IF (MEND < 0 .OR. sigma0_temp > wend + 15.0) EXIT
   IF ( (mol_temp .EQ. 2 .AND. iso_temp .EQ. 9) .OR. (mol_temp .EQ. 2 .AND. iso_temp .EQ. 10) &
        .OR. (mol_temp .EQ. 6 .AND. iso_temp .EQ. 4) .OR. (mol_temp .EQ. 27 .AND. iso_temp .EQ. 2) &
        .OR. (mol_temp .EQ. 40) ) CYCLE

   ! only count lines for the specified molecule
   IF (mol_temp == molnum .AND. sigma0_temp > wstart - 15.0 ) THEN
      if_q(mol_temp, iso_temp) = .TRUE.
      mol(i) = mol_temp
      iso(i) = iso_temp
      sigma0(i) = sigma0_temp
      
      !Correction the intensity for O2 Delta bands
      IF (molnum == 7 .AND. sigma0_temp > 16666. .AND. sigma0_temp < 17545.) strnth_temp = strnth_temp / 1.8

      strnth(i) = strnth_temp
      einstein(i) = einstein_temp
      alpha(i) = alpha_temp
      selfbrdn(i) = selfbrdn_temp
      elow(i)  = elow_temp
      coeff(i) = coeff_temp
      pshift(i) = pshift_temp
      i = i + 1
   ENDIF
ENDDO
CLOSE(unit = 22)
nlines = i - 1
IF (write_diagnostics) WRITE (*, *) 'nlines = ', nlines
IF (fwhm > 0.0d0) THEN ! do line by line calculation only around lines
   IF (wstart < sigma0(1)) wstart = sigma0(1)
   IF (wend > sigma0(nlines)) wend = sigma0(nlines)
   IF (write_diagnostics) WRITE(*, *) 'updated wstart = ', wstart, ' wend = ', wend
ENDIF

IF (nlines > maxlines) THEN
   WRITE(*, *) 'Nlines > maxlines, need to increase maxlines.!!!'
   errstat = 1; RETURN
ELSE IF (nlines == 0) THEN
   WRITE(*, *) hitran_filename
   WRITE(*, *) wstart, wend
   WRITE(*, *) 'No absorption lines are found in this spectral range!!!'
   crs = 0.0d0
   !errstat = 1; 
   RETURN
ENDIF

! Determine step size (to avoid undersampling)
minline_vg = MINVAL(4.30140d-7 * sigma0(1:nlines) * dsqrt (t0 / amu(molnum, 1)))   ! it is hw1e
IF (is_wavenum) THEN
   minslit_fwhm = fwhm 
ELSE
   minslit_fwhm = (1.0D7/lambda(nlambda) - 1.0D7/(lambda(nlambda) + fwhm))
ENDIF
!min_fwhm = SQRT(minslit_fwhm ** 2.0 + minline_vg ** 2.0)
min_fwhm = minline_vg 
step = min_fwhm * 0.555

! Step size should at least be as fine as the input grid
! IF fwhm == 0, then set step size to be the same as input spectral grid
IF (fwhm == 0.0) THEN
   IF ((wend - wstart) / (nlambda - 1) > step) THEN
      WRITE(*, *) 'Input spectral interval might be too large to resolve the spectral lines!!!'
   ENDIF
   step = (wend - wstart) / (nlambda - 1)    
ELSE
   step = MIN(step, (wend - wstart) / (nlambda - 1)) 
ENDIF

IF (write_diagnostics) WRITE(*, *) 'minline_vg = ', minline_vg, ' minslit_fwhm = ', minslit_fwhm
IF (write_diagnostics) WRITE(*, *) 'Wavenumber step = ', step

! Determine nvoigt
maxline_vg = MAXVAL(4.30140d-7 * sigma0(1:nlines) * dsqrt (t0 / amu(molnum, 1)))    ! it is hwle
maxline_hwhm = MAXVAL(ps) * MAXVAL(alpha(1:nlines))
IF (write_diagnostics) WRITE(*, *) 'maxline_vg = ', maxline_vg, ' maxline_hwhm = ', maxline_hwhm
voigt_extra = MAX(maxline_hwhm * 100.0, maxline_vg * 3.035)   ! for hw1e
nvoigt = INT(voigt_extra / step)
voigt_extra = nvoigt * step
IF (write_diagnostics) WRITE(*, *) 'voigt_extra = ', voigt_extra, ' nvoigt = ', nvoigt

! Establish wavenumber position
! IF fwhm == 0.0, include the exact original input grid with extra edges
IF (fwhm > 0.0d0) THEN
   npoints = (wend - wstart) / step + 2 * nvoigt
   IF (npoints > maxpoints) THEN
      WRITE(*, *) 'Npoints > maxpoints, need to increase maxpoints.!!!',npoints
      errstat = 1; RETURN
   ENDIF
   
   DO i = 1, npoints
      pos(i) = wstart - voigt_extra + (i - 1) * step
   ENDDO
ELSE
   npoints = nlambda + 2 * nvoigt
   IF (npoints > maxpoints) THEN
      WRITE(*, *) 'Npoints > maxpoints, need to increase maxpoints.!!!'
      errstat = 1; RETURN
   ENDIF
  
   IF (is_wavenum) THEN
      pos(nvoigt + 1:nvoigt + nlambda) = lambda(1:nlambda)
   ELSE
      pos(nvoigt + 1:nvoigt + nlambda) = 1.0D7/lambda(1:nlambda)
      CALL REVERSE(pos(nvoigt + 1:nvoigt + nlambda), nlambda)
   ENDIF

   DO i = nvoigt, 1, -1
      pos(i) = pos(i + 1) - step
   ENDDO

   DO i = nvoigt + nlambda + 1, npoints
      pos(i) = pos(i - 1) + step
   ENDDO
ENDIF

posnm(1:npoints) = 1.0D7 / pos(1:npoints)
CALL REVERSE(posnm(1:npoints), npoints)

! solar reference corresponding to posnm 
CALL bspline (i0wave(1:ni0), hi0(1:ni0), ni0, posnm(1:npoints), hi0new(1:npoints), npoints, errstat)   
IF ( errstat < 0 ) THEN
   WRITE(*, *) 'BSPLINE interpolation error!!!'
   errstat = 1; RETURN
   RETURN
ENDIF
IF (.NOT. is_wavenum .AND. .NOT. is_fwhm_inlam) THEN
   hi0new1(1:npoints) = hi0new(1:npoints)
   CALL REVERSE(hi0new1(1:npoints), npoints) ! corresponding pos
ENDIF

IF (write_diagnostics) THEN
   WRITE(*, *) 'npoints = ', npoints, ' nlambda = ', nlambda
   WRITE(*, *) 'pos(1) = ', pos(1), ' pos(npoints) = ', pos(npoints)
   WRITE(*, *) 'posnm(1) = ', posnm(1), ' posnm(npoints) = ', posnm(npoints)
ENDIF    

temp = 296.0
CALL q_lookup (maxmols, maxiso, q_input, molnum, temp, if_q, q296)

IF (PRESENT(crsdt)) THEN
   niter = 2      ! Calculate T sensitivity dcrs/dt using finite difference
ELSE
   niter = 1
ENDIF
niter = 1

! Output grid in wave number
IF (is_wavenum) THEN
   wavenum(1:nlambda) = lambda(1:nlambda)
ELSE
   wavenum(1:nlambda) = 1.0D7/lambda(1:nlambda)
   CALL REVERSE(wavenum(1:nlambda), nlambda) ! Wave number in incoreasing order
ENDIF

DO iter = 1, niter

   ! Loop over altitude
   DO iz = 1, nz
      IF (write_diagnostics) print *, iter, iz, ps(iz), ts(iz)

      ! initialize cross sections and calculate the spectrum grid.
      spec(1:npoints) = 0.d0
      IF (iter == 1 .AND. niter == 2) THEN
         temp = ts(iz)-1.0
      ELSE
         temp = ts(iz)  ! Perturb 1.0 degree
      ENDIF
      press = ps(iz)

      CALL q_lookup (maxmols, maxiso, q_input, molnum, temp, if_q, q)

      ! loop over lines to fill out cross section array
      rt0t = t0 / temp; rc2t = c2 / temp; rc2t0 = c2 / t0
      DO i = 1, nlines
         sigma_temp = sigma0(i) + pshift(i) * press  ! Add pressure induced shift
         
         vg = 4.30140d-7 * sigma_temp * dsqrt (temp / amu (mol (i), iso(i)))
         voigta = press * alpha(i) * (rt0t)**coeff(i) / vg
         ratio1 = dexp(-elow(i) * rc2t) - dexp(-(sigma_temp + elow(i)) * rc2t)
         ratio2 = dexp(-elow(i) * rc2t0) - dexp(-(sigma_temp + elow(i)) * rc2t0)

         ratio = ratio1 / ratio2 * q296(mol(i), iso(i)) / q(mol(i), iso(i))
         vnorm = ratio * strnth(i) / vg
         idx = ibin (sigma_temp, pos, npoints)
         IF (idx == 0) THEN
            IF (sigma_temp < pos(1) - voigt_extra .OR. sigma_temp > pos(npoints) + voigt_extra) THEN
               nvlo = 0; nvhi = 0
            ELSE IF (sigma_temp < pos(1)) THEN
               nvlo = 1; nvhi = nvoigt
            ELSE
               nvlo = npoints - nvoigt + 1
               nvhi = npoints
            ENDIF
         ELSE
            nvlo = MAX(1, idx - nvoigt)
            nvhi = MIN(npoints, idx + nvoigt)
         ENDIF
         ntemp = nvhi - nvlo + 1

         IF (ntemp > 0) THEN  
            voigtx(nvlo:nvhi) = (pos(nvlo:nvhi) - sigma_temp) / vg
            IF (.NOT. use_humlik) THEN
               CALL voigt (voigtx(1:npoints), voigta, v(1:npoints), npoints, nvlo, nvhi)   
            ELSE
               vnorm = vnorm * 1.d0 / SQRT(pi)
               CALL HUMLIK ( ntemp, voigtx(nvlo:nvhi), voigta, v(nvlo:nvhi) ) ! Faster by 5 times, but less accurate
            ENDIF
            spec(nvlo:nvhi) = spec(nvlo:nvhi) + vnorm * v(nvlo:nvhi)
         ENDIF
         !IF (write_diagnostics .AND. iz == 1) WRITE(*, '(5I6,2D14.5)') i, idx, nvlo, nvhi, npoints, voigta, vg
      ENDDO

      ! convolve with instrument function
      IF (fwhm > 0.0d0) THEN
         ! is_wavenum is always .false. , set in geocape_xsecs_prep.f90
         ! but fwhm (i.e., lambda_resolution could still be in wavenumber)
         IF (is_wavenum ) THEN
            CALL gauss_f2ci0 (pos(1:npoints), spec(1:npoints), hi0new(1:npoints), npoints, 1,  &
                 scale, fwhm, lambda(1:nlambda), crs(1:nlambda, iz), nlambda)         
         ELSE
            IF ( is_fwhm_inlam ) THEN
               CALL REVERSE(spec(1:npoints), npoints)
               CALL gauss_f2ci0 (posnm(1:npoints), spec(1:npoints),  hi0new(1:npoints), npoints, 1, &
                    scale, fwhm, lambda(1:nlambda), crs(1:nlambda, iz), nlambda) 
            ELSE ! lambda is in wavelength, but fwhm is in wavenumber
               CALL gauss_f2ci0 (pos(1:npoints), spec(1:npoints), hi0new1(1:npoints), npoints, 1,  &
                    scale, fwhm, wavenum(1:nlambda), crs(1:nlambda, iz), nlambda)  
               CALL REVERSE(crs(1:nlambda, iz), nlambda)
            ENDIF
         ENDIF
      ELSE
         crs(1:nlambda, iz) = spec(nvoigt + 1:nvoigt + nlambda)
         IF (.NOT. is_wavenum) CALL REVERSE(crs(1:nlambda, iz), nlambda)
      ENDIF
   ENDDO

   IF (iter == 1 .AND. niter == 2) THEN
      crsdt(1:nlambda, 1:nz) = crs(1:nlambda, 1:nz)
   ENDIF

   IF (iter == 2) THEN
      crsdt(1:nlambda, 1:nz) = (crs(1:nlambda, 1:nz) - crsdt(1:nlambda, 1:nz))
   ENDIF
ENDDO

RETURN

END SUBROUTINE  get_hitran_crs
!


SUBROUTINE hitran_setup (maxmols, maxiso, amu)

IMPLICIT NONE
INTEGER, INTENT(IN)                                   :: maxmols, maxiso
REAL(KIND=8), DIMENSION(maxmols, maxiso), INTENT(OUT) :: amu

! hitran numbers: h2o (1), co2 (2), o3 (3), n2o (4), co (5), ch4 (6), o2 (7),
! no (8), so2 (9), no2 (10), nh3 (11), hno3 (12), oh (13), hf (14), hcl (15),
! hbr (16), hi (17), clo (18), ocs (19), h2co (20), hocl (21), n2 (22),
! hcn (23), ch3cl (24), h2o2 (25), c2h2 (26), c2h6 (27), ph3 (28), cof2 (29),
! sf6 (30), h2s (31), hcooh (32), ho2 (33), o (34), clono2 (35), no+ (36),
! hobr (37), c2h4 (38), ch3oh (39), ch3br (40; not included in parsum.dat),
! ch3cn (41), cf4 (42)

amu = 0.d0
amu (1, 1) = 18.010565
amu (1, 2) = 20.014811
amu (1, 3) = 19.014780
amu (1, 4) = 19.016740
amu (1, 5) = 21.020985
amu (1, 6) = 20.020956
amu (2, 1) = 43.989830
amu (2, 2) = 44.993185
amu (2, 3) = 45.994076
amu (2, 4) = 44.994045
amu (2, 5) = 46.997431
amu (2, 6) = 45.997400
amu (2, 7) = 47.998322
amu (2, 8) = 46.998291
amu (3, 1) = 47.984745
amu (3, 2) = 49.988991
amu (3, 3) = 49.988991
amu (3, 4) = 48.988960
amu (3, 5) = 48.988960
amu (4, 1) = 44.001062
amu (4, 2) = 44.998096
amu (4, 3) = 44.998096
amu (4, 4) = 46.005308
amu (4, 5) = 45.005278
amu (5, 1) = 27.994915
amu (5, 2) = 28.998270
amu (5, 3) = 29.999161
amu (5, 4) = 28.999130
amu (5, 5) = 31.002516
amu (5, 6) = 30.002485
amu (6, 1) = 16.031300
amu (6, 2) = 17.034655
amu (6, 3) = 17.037475
amu (7, 1) = 31.989830
amu (7, 2) = 33.994076
amu (7, 3) = 32.994045
amu (8, 1) = 29.997989
amu (8, 2) = 30.995023
amu (8, 3) = 32.002234
amu (9, 1) = 63.961901
amu (9, 2) = 65.957695
amu (10, 1) = 45.992904
amu (11, 1) = 17.026549
amu (11, 2) = 18.023583
amu (12, 1) = 62.995644
amu (13, 1) = 17.002740
amu (13, 2) = 19.006986
amu (13, 3) = 18.008915
amu (14, 1) = 20.006229
amu (15, 1) = 35.976678
amu (15, 2) = 37.973729
amu (16, 1) = 79.926160
amu (16, 2) = 81.924115
amu (17, 1) = 127.912297
amu (18, 1) = 50.963768
amu (18, 2) = 52.960819
amu (19, 1) = 59.966986
amu (19, 2) = 61.962780
amu (19, 3) = 60.970341
amu (19, 4) = 60.966371
amu (19, 5) = 61.971231
amu (20, 1) = 30.010565
amu (20, 2) = 31.013920
amu (20, 3) = 32.014811
amu (21, 1) = 51.971593
amu (21, 2) = 53.968644
amu (22, 1) = 28.006147
amu (23, 1) = 27.010899
amu (23, 2) = 28.014254
amu (23, 3) = 28.007933
amu (24, 1) = 49.992328
amu (24, 2) = 51.989379
amu (25, 1) = 34.005480
amu (26, 1) = 26.015650
amu (26, 2) = 27.019005
amu (27, 1) = 30.046950
amu (28, 1) = 33.997238
amu (29, 1) = 65.991722
amu (30, 1) = 145.962492
amu (31, 1) = 33.987721
amu (31, 2) = 35.983515
amu (31, 3) = 34.987105
amu (32, 1) = 46.005480
amu (33, 1) = 32.997655
amu (34, 1) = 15.994915
amu (35, 1) = 96.956672
amu (35, 2) = 98.953723
amu (36, 1) = 29.997989
amu (37, 1) = 95.921076
amu (37, 2) = 97.919027
amu (38, 1) = 28.031300
amu (38, 2) = 29.034655
amu (39, 1) = 32.026215
amu (41, 1) = 41.026549
amu (42, 1) = 87.993616

RETURN
END SUBROUTINE hitran_setup

SUBROUTINE q_lookup (maxmols, maxiso, q_input, molnum, temp, if_q, q)

! 3rd order lagrange interpolation, for evenly-spaced x-values. the known values
! of x = -1, 0, 1, 2. the unknown x normally is 0 < x < 1, although that is not
! strictly necessary (the intent is to interpolate more evenly).

IMPLICIT none
INTEGER, INTENT(IN)      :: maxmols, maxiso, molnum
REAL(KIND=8), INTENT(IN) :: temp
LOGICAL, DIMENSION(maxmols, maxiso), INTENT(IN)               :: if_q
REAL(KIND=8), DIMENSION(maxmols, maxiso, 148:342), INTENT(IN) :: q_input
REAL (kind=8), DIMENSION(maxmols, maxiso), INTENT(OUT)        :: q

INTEGER       :: ia, ib, ic, id, i, j
REAL(KIND=8)  :: tcalc, ya, yb, yc, yd, a, b, c, d

!LOGICAL, SAVE :: first_call = .true.
LOGICAL       :: temp_int

q = 0.d0
temp_int = .FALSE.

! temperature limits (148 - 342 degrees included here for interpolation of
! partition functions for 150 - 340 degrees).
IF (temp .LT. 150.d0 .OR. temp .GT. 340.d0) THEN
  WRITE (*, *) 'temperature out of bounds'
  STOP
END IF

!IF (first_call) THEN
!  first_call = .FALSE.
!  CALL q_load (maxmols, maxiso, q_input)
!  WRITE (*, *) 'partition function database loaded'
!END IF

! find q for the input temperature (= temp) interpolating IF necessary.
! ib = int (temp) is the location of temperature just below temp in the evenly-
! spaced array of q values. interpolate among ib - 1, ib, ib + 1, ib + 2.
ib = INT (temp)
! integral value of temperature? IF so, don't interpolate.
IF (temp .EQ. AINT (temp)) THEN
  temp_int = .TRUE.
ELSE
! non-integral values.
  ia = ib - 1
  ic = ib + 1
  id = ib + 2
  tcalc = temp - ib
END IF

! calculate q (i, j) for existing mol, iso pairs
DO i = molnum, molnum
  DO j = 1, maxiso
    IF (if_q (i, j)) THEN
      IF (temp_int) THEN
!       don't interpolate
        q (i, j) = q_input (i, j, ib)
      ELSE
!       interpolate
        ya = q_input (i, j, ia)
        yb = q_input (i, j, ib)
        yc = q_input (i, j, ic)
        yd = q_input (i, j, id)
        a = tcalc + 1.d0
        b = tcalc
        c = tcalc - 1.d0
        d = tcalc - 2.d0
        q (i, j) = - (ya * b * c * d / 6.d0) + (yb * a * c * d / 2.d0) - &
        (yc * a * b * d / 2.d0) + (yd * a * b * c / 6.d0)
      END IF
    END IF
  END DO
END DO

RETURN
END SUBROUTINE q_lookup


SUBROUTINE q_load (maxmols, maxiso, q_input)

IMPLICIT NONE
INTEGER, INTENT(IN) :: maxmols, maxiso
REAL (kind=8), DIMENSION(maxmols, maxiso, 148:342), INTENT(out) :: q_input

INTEGER             :: i, j, k, l
CHARACTER (len=132) :: q_file 

q_input = 0.d0
q_file  = '../geocape_data/HITRAN/hitran08-parsum.resorted'

OPEN (unit = 22, file = q_file, status = 'old')

DO i = 1, 95
   READ (22, *) j, k
   DO l = 148, 342
      READ (22, *) q_input (j, k, l)
   ENDDO
ENDDO

CLOSE (unit = 22)
RETURN
END SUBROUTINE q_load


SUBROUTINE voigt (x, a, v, ndim, nvlo, nvhi)

! the following calculated voigt values at all grid values for each point
! subroutine voigt (x, a, v, nx)
! voigt first and second derivatives commented out
! subroutine voigt (x, a, v, dv, d2v, nx)

IMPLICIT NONE
INTEGER, INTENT(IN)      :: ndim, nvlo, nvhi
REAL(KIND=8), INTENT(IN) :: a
REAL(KIND=8), DIMENSION(ndim), INTENT(IN)  :: x
REAL(KIND=8), DIMENSION(ndim), INTENT(OUT) :: v ! , dv, d2v 

REAL (KIND=8), PARAMETER  :: sqrtpi =1.77245385090551d0, &
     twooverpi = 0.63661977236758d0,  fouroverpi = 1.27323954473516d0

INTEGER      :: capn, i, nu, n, in, np1
REAL(KIND=8) :: lamda, sfac, absx, s, h, h2, r1, r2, s1, s2, t1, t2, c !, c2v
LOGICAL      :: b

! a = 0.
IF (a < 1.0d-8) THEN
   v(nvlo:nvhi) = dexp(-x(nvlo:nvhi)**2) / sqrtpi
   !dv(nvlo:nvhi) = -2.0d0 * x(nvlo:nvhi) * v(nvlo:nvhi)
   !d2v(nvlo:nvhi) = (4.0d0 * x(nvlo:nvhi) ** 2 - 2.d0) * v(nvlo:nvhi)

   ! add lorentzian check here, for speed
ELSE
  ! coefficient for second derivative
  ! c2v = 4.0d0 * a * a + 2.d0

  sfac = 1.0d0 - a / 4.29d0
  DO i = nvlo, nvhi
  ! do i = 1, nx
     absx = dabs (x (i))
     IF ((a < 4.29d0) .AND. (absx < 5.33d0)) THEN
        s = sfac * dsqrt (1.d0 - (x (i) / 5.33d0)**2)
        h = 1.6d0 * s
        h2 = 2.0d0 * h
        capn = 6.d0 + 23.0d0 * s
        lamda = h2**capn
        nu = 9.0d0 + 21.0d0 * s
     ELSE
        h = 0.0d0
        capn = 0
        nu = 8
     ENDIF
     b = (h == 0.0d0) .or. (lamda == 0.0d0)
     r1 = 0.0d0
     r2 = 0.0d0
     s1 = 0.0d0
     s2 = 0.0d0
     n = nu
     DO in = 1, nu + 1
        np1 = n + 1
        t1 = a + h + dfloat (np1) * r1
        t2 = absx - dfloat (np1) * r2
        c = .5d0 / (t1 * t1 + t2 * t2)
        r1 = c * t1
        r2 = c * t2
        IF ((h > 0.0d0) .AND. (n <= capn)) THEN
           t1 = lamda + s1
           s1 = r1 * t1 - r2 * s2
           s2 = r2 * t1 + r1 * s2
           lamda = lamda / h2
        ENDIF
        n = n - 1
     ENDDO
     IF (b) THEN
        v (i) = twooverpi * r1
        !     dv (i) = fouroverpi * (a * r2 - absx * r1)
     ELSE
        v (i) = twooverpi * s1
        !     dv (i) = fouroverpi * (a * s2 - absx * s1)
     ENDIF
     !   dv (i) = -dsign (dv (i), x (i))
     !   d2v (i) = fouroverpi * a - (c2v + 4.d0 * x (i) * x (i)) * &
     !   v (i) - 4.d0 * x (i) * dv (i)
  ENDDO
ENDIF

RETURN
END SUBROUTINE voigt


FUNCTION ibin (vtarget, array, nentries) RESULT(idx)

! binary search in an array of real numbers in increasing order.
! returned is the number of the last entry which is less than target, or
! 0 if not within array. (this was written to find values enclosing
! target for a linear interpolation scheme.) 4/9/84 john lavagnino;
! adapted from jon bentley, cacm february 1984, vol. 27, no. 2, p. 94.

IMPLICIT NONE
INTEGER, INTENT(IN)      :: nentries
REAL(KIND=8), INTENT(IN) :: vtarget
REAL(KIND=8), DIMENSION(nentries), INTENT(IN) :: array

INTEGER :: upper, lower, middle
INTEGER :: idx

lower = 0
upper = nentries + 1

DO WHILE (lower + 1 /= upper)
  middle = (lower + upper) / 2
  IF (array(middle) < vtarget) THEN
     lower = middle
  ELSE
     upper = middle
  ENDIF
ENDDO

! at this point, either array (lower) <= target <= array (upper), or
! lower = 0, or upper = nentries + 1 (initial values).
IF (lower > 0 .and. upper /= nentries + 1) THEN
   idx = lower
ELSE
   idx = 0
ENDIF

END FUNCTION ibin

!------------------------------------------------------------------------------
!S+
! NAME:
!       StrUpCase
!
! PURPOSE:
!       Function to convert an input string to upper case.
!
! CATEGORY:
!       Utility
!
! LANGUAGE:
!       Fortran-95
!
! CALLING SEQUENCE:
!       Result = StrUpCase( String )
!
! INPUT ARGUMENTS:
!       String:  Character string to be converted to upper case.
!                UNITS:      N/A
!                TYPE:       CHARACTER( * )
!                DIMENSION:  Scalar
!                ATTRIBUTES: INTENT( IN )
!
! OPTIONAL INPUT ARGUMENTS:
!       None.
!
! OUTPUT ARGUMENTS:
!       None.
!
! OPTIONAL OUTPUT ARGUMENTS:
!       None.
!
! FUNCTION RESULT:
!       Result:  The input character string converted to upper case.
!                UNITS:      N/A
!                TYPE:       CHARACTER( LEN(String) )
!                DIMENSION:  Scalar
!
! CALLS:
!       None.
!
! SIDE EFFECTS:
!       None.
!
! RESTRICTIONS:
!       None.
!
! EXAMPLE:
!       string = 'this is a string'
!       WRITE( *, '( a )' ) StrUpCase( string )
!   THIS IS A STRING
!
! PROCEDURE:
!       Figure 3.5B, pg 80, "Upgrading to Fortran 90", by Cooper Redwine,
!       1995 Springer-Verlag, New York.
!
! CREATION HISTORY:
!       Written by:     Paul van Delst, CIMSS/SSEC 18-Oct-1999
!                       paul.vandelst@ssec.wisc.edu
!S-
!------------------------------------------------------------------------------

FUNCTION StrUpCase ( Input_String ) RESULT ( Output_String )
  
  ! -- Argument and result
  CHARACTER( * ), INTENT( IN )     :: Input_String
  CHARACTER( LEN( Input_String ) ) :: Output_String
  
  CHARACTER( * ), PARAMETER :: LOWER_CASE = 'abcdefghijklmnopqrstuvwxyz'
  CHARACTER( * ), PARAMETER :: UPPER_CASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 
  
  ! -- Local variables
  INTEGER :: i, n
  
  ! -- Copy input string
  Output_String = Input_String
  
  ! -- Loop over string elements
  DO i = 1, LEN( Output_String )
     
     ! -- Find location of letter in lower case constant string
     n = INDEX( LOWER_CASE, Output_String( i:i ) )
     
     ! -- If current substring is a lower case letter, make it upper case
     IF ( n /= 0 ) Output_String( i:i ) = UPPER_CASE( n:n )
     
  END DO
  
END FUNCTION StrUpCase


!------------------------------------------------------------------------------
!S+
! NAME:
!       StrLowCase
!
! PURPOSE:
!       Function to convert an input string to lower case.
!
! CATEGORY:
!       Utility
!
! LANGUAGE:
!       Fortran-95
!
! CALLING SEQUENCE:
!       Result = StrLowCase( String )
!
! INPUT ARGUMENTS:
!       String: Character string to be converted to lower case.
!               UNITS:      N/A
!               TYPE:       CHARACTER( * )
!               DIMENSION:  Scalar
!               ATTRIBUTES: INTENT( IN )
!
! OPTIONAL INPUT ARGUMENTS:
!       None.
!
! OUTPUT ARGUMENTS:
!       None.
!
! OPTIONAL OUTPUT ARGUMENTS:
!       None.
!
! FUNCTION RESULT:
!       Result:  The input character string converted to lower case.
!                UNITS:      N/A
!                TYPE:       CHARACTER( LEN(String) )
!                DIMENSION:  Scalar
!
! CALLS:
!       None.
!
! SIDE EFFECTS:
!       None.
!
! RESTRICTIONS:
!       None.
!
! EXAMPLE:
!       string = 'THIS IS A STRING'
!       WRITE( *, '( a )' ) StrLowCase( string )
!   this is a string
!
! PROCEDURE:
!       Figure 3.5B, pg 80, "Upgrading to Fortran 90", by Cooper Redwine,
!       1995 Springer-Verlag, New York.
!
! CREATION HISTORY:
!       Written by:     Paul van Delst, CIMSS/SSEC 18-Oct-1999
!                       paul.vandelst@ssec.wisc.edu
!S-
!------------------------------------------------------------------------------

FUNCTION StrLowCase ( Input_String ) RESULT ( Output_String )
  
  ! -- Argument and result
  CHARACTER( * ), INTENT( IN )     :: Input_String
  CHARACTER( LEN( Input_String ) ) :: Output_String
  
  CHARACTER( * ), PARAMETER :: LOWER_CASE = 'abcdefghijklmnopqrstuvwxyz'
  CHARACTER( * ), PARAMETER :: UPPER_CASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 
  
  ! -- Local variables
  INTEGER :: i, n
  
  
  ! -- Copy input string
  Output_String = Input_String
  
  ! -- Loop over string elements
  DO i = 1, LEN( Output_String )
     
     ! -- Find location of letter in upper case constant string
     n = INDEX( UPPER_CASE, Output_String( i:i ) )
     
     ! -- If current substring is an upper case letter, make it lower case
     IF ( n /= 0 ) Output_String( i:i ) = LOWER_CASE( n:n )
     
  END DO
  
END FUNCTION StrLowCase

SUBROUTINE reverse ( inarr, num )
  IMPLICIT NONE
  INTEGER, PARAMETER :: dp = KIND(1.0D0)

  INTEGER, INTENT(IN) :: num
  INTEGER             :: i
  REAL (KIND=dp), DIMENSION(1: num), INTENT(INOUT) :: inarr
  REAL (KIND=dp), DIMENSION(1: num)                :: temp

  DO i = 1, num
     temp(i) = inarr(num - i + 1)
  ENDDO
  inarr = temp

  RETURN
END SUBROUTINE reverse

SUBROUTINE reverse_idxs (num, idxs )
  IMPLICIT NONE

  INTEGER,                  INTENT(IN) :: num
  INTEGER, DIMENSION(num), INTENT(OUT) :: idxs
  INTEGER                              :: i

  DO i = 1, num
     idxs(i) = num - i + 1
  ENDDO

  RETURN
END SUBROUTINE reverse_idxs


SUBROUTINE HUMLIK ( N, X, Y, K )

!     To calculate the Faddeeva function with relative error less than 10^(-4).

! Arguments
INTEGER N                                                         ! IN   Number of points
REAL*8    X(0:N-1)                                                  ! IN   Input x array
REAL*8    Y                                                         ! IN   Input y value >=0.0
REAL*8    K(0:N-1)                                                  ! OUT  Real (Voigt) array

! Constants
REAL        RRTPI                                                 ! 1/SQRT(pi)
PARAMETER ( RRTPI = 0.56418958 )
REAL        Y0,       Y0PY0,         Y0Q                          ! for CPF12 algorithm
PARAMETER ( Y0 = 1.5, Y0PY0 = Y0+Y0, Y0Q = Y0*Y0  )
REAL  C(0:5), S(0:5), T(0:5)
SAVE  C,      S,      T
!     SAVE preserves values of C, S and T (static) arrays between procedure calls
DATA C / 1.0117281,     -0.75197147,        0.012557727, &
     0.010022008,   -0.00024206814,     0.00000050084806 /
DATA S / 1.393237,       0.23115241,       -0.15535147,  &
     0.0062183662,   0.000091908299,   -0.00000062752596 /
DATA T / 0.31424038,     0.94778839,        1.5976826,  &
     2.2795071,      3.0206370,         3.8897249 /

! Local variables
INTEGER I, J                                                      ! Loop variables
INTEGER RG1, RG2, RG3                                             ! y polynomial flags
REAL ABX, XQ, YQ, YRRTPI                                          ! |x|, x^2, y^2, y/SQRT(pi)
REAL XLIM0, XLIM1, XLIM2, XLIM3, XLIM4                            ! |x| on region boundaries
REAL A0, D0, D2, E0, E2, E4, H0, H2, H4, H6                       ! W4 temporary variables
REAL P0, P2, P4, P6, P8, Z0, Z2, Z4, Z6, Z8
REAL XP(0:5), XM(0:5), YP(0:5), YM(0:5)                           ! CPF12 temporary values
REAL MQ(0:5), PQ(0:5), MF(0:5), PF(0:5)
REAL D, YF, YPY0, YPY0Q  

!***** Start of executable code *****************************************

YQ  = Y*Y                                                         ! y^2
YRRTPI = Y*RRTPI                                                  ! y/SQRT(pi)

IF ( Y .GE. 70.55 ) THEN                                          ! All points
   DO I = 0, N-1                                                   ! in Region 0
      XQ   = X(I)*X(I)
      K(I) = YRRTPI / (XQ + YQ)
   ENDDO
   RETURN
ENDIF

RG1 = 1                                                           ! Set flags
RG2 = 1
RG3 = 1

XLIM0 = SQRT ( 15100.0 + Y*(40.0 - Y*3.6) )                       ! y<70.55
IF ( Y .GE. 8.425 ) THEN
   XLIM1 = 0.0
ELSE
   XLIM1 = SQRT ( 164.0 - Y*(4.3 + Y*1.8) )
ENDIF
XLIM2 = 6.8 - Y
XLIM3 = 2.4*Y
XLIM4 = 18.1*Y + 1.65
IF ( Y .LE. 0.000001 ) THEN                                       ! When y<10^-6
   XLIM1 = XLIM0                                                    ! avoid W4 algorithm
   XLIM2 = XLIM0
ENDIF
!.....
DO I = 0, N-1                                                     ! Loop over all points
   ABX = ABS ( X(I) )                                               ! |x|
   XQ  = ABX*ABX                                                    ! x^2
   IF     ( ABX .GE. XLIM0 ) THEN                                   ! Region 0 algorithm
      K(I) = YRRTPI / (XQ + YQ)
      
   ELSEIF ( ABX .GE. XLIM1 ) THEN                                   ! Humlicek W4 Region 1
      IF ( RG1 .NE. 0 ) THEN                                          ! First point in Region 1
         RG1 = 0
         A0 = YQ + 0.5                                                  ! Region 1 y-dependents
         D0 = A0*A0
         D2 = YQ + YQ - 1.0
      ENDIF
      D = RRTPI / (D0 + XQ*(D2 + XQ))
      K(I) = D*Y   *(A0 + XQ)
      
   ELSEIF ( ABX .GT. XLIM2 ) THEN                                   ! Humlicek W4 Region 2 
      IF ( RG2 .NE. 0 ) THEN                                          ! First point in Region 2
         RG2 = 0
         H0 =  0.5625 + YQ*(4.5 + YQ*(10.5 + YQ*(6.0 + YQ)))            ! Region 2 y-dependents
         H2 = -4.5    + YQ*(9.0 + YQ*( 6.0 + YQ* 4.0))
         H4 = 10.5    - YQ*(6.0 - YQ*  6.0)
         H6 = -6.0    + YQ* 4.0
         E0 =  1.875  + YQ*(8.25 + YQ*(5.5 + YQ))
         E2 =  5.25   + YQ*(1.0  + YQ* 3.0)
         E4 =  0.75*H6
      ENDIF
      D = RRTPI / (H0 + XQ*(H2 + XQ*(H4 + XQ*(H6 + XQ))))
      K(I) = D*Y   *(E0 + XQ*(E2 + XQ*(E4 + XQ)))
      
   ELSEIF ( ABX .LT. XLIM3 ) THEN                                   ! Humlicek W4 Region 3
      IF ( RG3 .NE. 0 ) THEN                                          ! First point in Region 3
         RG3 = 0
         Z0 = 272.1014     + Y*(1280.829 + Y*(2802.870 + Y*(3764.966  &    ! Region 3 y-dependents
              + Y*(3447.629 + Y*(2256.981 + Y*(1074.409 + Y*(369.1989 &
              + Y*(88.26741 + Y*(13.39880 + Y)))))))))
         Z2 = 211.678      + Y*(902.3066 + Y*(1758.336 + Y*(2037.310  &
              + Y*(1549.675 + Y*(793.4273 + Y*(266.2987 &
              + Y*(53.59518 + Y*5.0)))))))
         Z4 = 78.86585     + Y*(308.1852 + Y*(497.3014 + Y*(479.2576  &
              + Y*(269.2916 + Y*(80.39278 + Y*10.0)))))
         Z6 = 22.03523     + Y*(55.02933 + Y*(92.75679 + Y*(53.59518  &
              + Y*10.0)))
         Z8 = 1.496460     + Y*(13.39880 + Y*5.0)
         P0 = 153.5168     + Y*(549.3954 + Y*(919.4955 + Y*(946.8970  &
              + Y*(662.8097 + Y*(328.2151 + Y*(115.3772 + Y*(27.93941 &
              + Y*(4.264678 + Y*0.3183291))))))))
         P2 = -34.16955    + Y*(-1.322256+ Y*(124.5975 + Y*(189.7730  &
              + Y*(139.4665 + Y*(56.81652 + Y*(12.79458               &
              + Y*1.2733163))))))
         P4 = 2.584042     + Y*(10.46332 + Y*(24.01655 + Y*(29.81482  &
              + Y*(12.79568 + Y*1.9099744))))
         P6 = -0.07272979  + Y*(0.9377051+ Y*(4.266322 + Y*1.273316))
         P8 = 0.0005480304 + Y*0.3183291
      ENDIF
      D = 1.7724538 / (Z0 + XQ*(Z2 + XQ*(Z4 + XQ*(Z6 + XQ*(Z8+XQ)))))
      K(I) = D*(P0 + XQ*(P2 + XQ*(P4 + XQ*(P6 + XQ*P8))))
      
   ELSE                                                             ! Humlicek CPF12 algorithm
      YPY0 = Y + Y0
      YPY0Q = YPY0*YPY0
      K(I) = 0.0
      DO J = 0, 5
         D = X(I) - T(J)
         MQ(J) = D*D
         MF(J) = 1.0 / (MQ(J) + YPY0Q)
         XM(J) = MF(J)*D
         YM(J) = MF(J)*YPY0
         D = X(I) + T(J)
         PQ(J) = D*D
         PF(J) = 1.0 / (PQ(J) + YPY0Q)
         XP(J) = PF(J)*D
         YP(J) = PF(J)*YPY0
      ENDDO
      
      IF ( ABX .LE. XLIM4 ) THEN                                      ! Humlicek CPF12 Region I
         DO J = 0, 5
            K(I) = K(I) + C(J)*(YM(J)+YP(J)) - S(J)*(XM(J)-XP(J))
         ENDDO
         
      ELSE                                                            ! Humlicek CPF12 Region II
         YF   = Y + Y0PY0
         DO J = 0, 5
            K(I) = K(I)   &
                 + (C(J)*(MQ(J)*MF(J)-Y0*YM(J)) + S(J)*YF*XM(J)) / (MQ(J)+Y0Q) &
                 + (C(J)*(PQ(J)*PF(J)-Y0*YP(J)) - S(J)*YF*XP(J)) / (PQ(J)+Y0Q)
         ENDDO
         K(I) = Y*K(I) + EXP ( -XQ )
      ENDIF
   ENDIF
ENDDO
!.....
END SUBROUTINE HUMLIK

