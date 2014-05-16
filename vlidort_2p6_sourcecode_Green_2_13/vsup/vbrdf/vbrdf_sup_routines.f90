! ###############################################################
! #                                                             #
! #                    THE VECTOR LIDORT MODEL                  #
! #                                                             #
! #  (Vector LInearized Discrete Ordinate Radiative Transfer)   #
! #   -      --         -        -        -         -           #
! #                                                             #
! ###############################################################

! ###############################################################
! #                                                             #
! #  Author :      Robert. J. D. Spurr                          #
! #                                                             #
! #  Address :     RT Solutions, inc.                           #
! #                9 Channing Street                            #
! #                Cambridge, MA 02138, USA                     #
! #                Tel: (617) 492 1183                          #
! #                                                             #
! #  Email :       rtsolutions@verizon.net                      #
! #                                                             #
! #  Versions     :   2.0, 2.2, 2.3, 2.4, 2.4R, 2.4RT, 2.4RTC,  #
! #                   2.5, 2.6, 2.7                             #
! #  Release Date :   December 2005  (2.0)                      #
! #  Release Date :   March 2007     (2.2)                      #
! #  Release Date :   October 2007   (2.3)                      #
! #  Release Date :   December 2008  (2.4)                      #
! #  Release Date :   April 2009     (2.4R)                     #
! #  Release Date :   July 2009      (2.4RT)                    #
! #  Release Date :   October 2010   (2.4RTC)                   #
! #  Release Date :   March 2011     (2.5)                      #
! #  Release Date :   May 2012       (2.6)                      #
! #  Release Date :   May   2014     (2.7)                      #
! #                                                             #
! #       NEW: TOTAL COLUMN JACOBIANS          (2.4)            #
! #       NEW: BPDF Land-surface KERNELS       (2.4R)           #
! #       NEW: Thermal Emission Treatment      (2.4RT)          #
! #       Consolidated BRDF treatment          (2.4RTC)         #
! #       f77/f90 Release                      (2.5)            #
! #       External SS / New I/O Structures     (2.6)            #
! #                                                             #
! #       Surface-leaving, BRDF Albedo-scaling (2.7)            # 
! #       Taylor series, Black-body Jacobians  (2.7)            #
! #                                                             #
! ###############################################################

!    #####################################################
!    #                                                   #
!    #   This Version of VLIDORT comes with a GNU-style  #
!    #   license. Please read the license carefully.     #
!    #                                                   #
!    #####################################################

! ###############################################################
! #                                                             #
! # Subroutines in this Module                                  #
! #                                                             #
! #              VBRDF_MAKER                                    #
! #              VBRDF_GCMCRI_MAKER                             #
! #              SCALING_FOURIER_ZERO                           #
! #              VBRDF_FOURIER                                  #
! #                                                             #
! ###############################################################


      MODULE vbrdf_sup_routines_m

      PRIVATE
      PUBLIC :: VBRDF_MAKER, &
                VBRDF_GCMCRI_MAKER, &
                VBRDF_FOURIER, SCALING_FOURIER_ZERO

      CONTAINS

      SUBROUTINE VBRDF_MAKER &
         ( BRDF_VFUNCTION, BRDF_VFUNCTION_DB,                                &
           DO_WSA_SCALING, DO_BSA_SCALING,                                   & ! New line, Version 2.7
           DO_SOLAR_SOURCES, DO_USER_OBSGEOMS, DO_EXACT,                     &
           DO_EXACTONLY, DO_MSRCORR, DO_MSRCORR_EXACTONLY, MSRCORR_ORDER,    &
           DO_USER_STREAMS, DO_SURFACE_EMISSION, N_MUQUAD, N_PHIQUAD,        &
           NSTREAMS_BRDF, NBRDF_HALF, NSTOKESSQ, BRDF_NPARS,                 &
           NSTREAMS, NBEAMS, N_USER_STREAMS, N_USER_RELAZMS,                 &
           QUAD_STREAMS, QUAD_SINES, USER_STREAMS, USER_SINES,               &
           SZASURCOS, SZASURSIN, PHIANG, COSPHI, SINPHI, BRDF_PARS,          &
           SCALING_NSTREAMS, SCALING_QUAD_STREAMS, SCALING_QUAD_SINES,       & ! New line, Version 2.7
           X_BRDF, CX_BRDF, SX_BRDF, CXE_BRDF, SXE_BRDF,                     &
           X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,  &
           DBKERNEL_BRDFUNC, BRDFUNC, USER_BRDFUNC,                          & ! output
           BRDFUNC_0, USER_BRDFUNC_0, EBRDFUNC, USER_EBRDFUNC,               & ! Output
           SCALING_BRDFUNC, SCALING_BRDFUNC_0  )                               ! output, New line, Version 2.7

!  include file of dimensions and numbers

      USE VLIDORT_PARS

      IMPLICIT NONE

!  Prepares the bidirectional reflectance scatter matrices

!  Observational Geometry Inputs. Marked with !@@
!     Installed 31 december 2012.
!     Observation-Geometry input control.         (DO_USER_OBSGEOMS)
!     Added solar_sources flag for better control (DO_SOLAR_SOURCES)
!     Added Overall-exact flag for better control (DO_EXACT)

!  Input arguments
!  ===============

!  BRDF functions (external calls)

      EXTERNAL         BRDF_VFUNCTION
      EXTERNAL         BRDF_VFUNCTION_DB

!  White-sky and Black-sky albedo scaling flags. New Version 2.7

      LOGICAL ::          DO_WSA_SCALING
      LOGICAL ::          DO_BSA_SCALING

!   !@@ Solar sources + Observational Geometry flag !@@

      LOGICAL ::          DO_SOLAR_SOURCES
      LOGICAL ::          DO_USER_OBSGEOMS

!  Exact flag (!@@) and Exact only flag --> no Fourier term calculations

      LOGICAL ::          DO_EXACT
      LOGICAL ::          DO_EXACTONLY

!  Multiple reflectance correction for Glitter kernels

      LOGICAL ::          DO_MSRCORR
      LOGICAL ::          DO_MSRCORR_EXACTONLY
      INTEGER ::          MSRCORR_ORDER
      INTEGER ::          N_MUQUAD, N_PHIQUAD

!  Local flags

      LOGICAL ::          DO_USER_STREAMS
      LOGICAL ::          DO_SURFACE_EMISSION

!  Number of Azimuth waudrature streams

      INTEGER ::          NSTREAMS_BRDF
      INTEGER ::          NBRDF_HALF

!  Local number of Stokes component matrix entries
!    value = 1 for most kernels, except GISS Cox-Munk

      INTEGER ::          NSTOKESSQ

!  Local number of Kernel parameters

      INTEGER ::          BRDF_NPARS

!  Local angle control

      INTEGER ::          NSTREAMS
      INTEGER ::          NBEAMS
      INTEGER ::          N_USER_STREAMS
      INTEGER ::          N_USER_RELAZMS

!  Local angles

      DOUBLE PRECISION :: PHIANG(MAX_USER_RELAZMS)
      DOUBLE PRECISION :: COSPHI(MAX_USER_RELAZMS)
      DOUBLE PRECISION :: SINPHI(MAX_USER_RELAZMS)

      DOUBLE PRECISION :: SZASURCOS(MAXBEAMS)
      DOUBLE PRECISION :: SZASURSIN(MAXBEAMS)

      DOUBLE PRECISION :: QUAD_STREAMS(MAXSTREAMS)
      DOUBLE PRECISION :: QUAD_SINES  (MAXSTREAMS)

      DOUBLE PRECISION :: USER_STREAMS(MAX_USER_STREAMS)
      DOUBLE PRECISION :: USER_SINES  (MAX_USER_STREAMS)

!  Discrete ordinates (local, for Albedo scaling). New Version 2.7

      INTEGER          :: SCALING_NSTREAMS
      DOUBLE PRECISION :: SCALING_QUAD_STREAMS(MAXSTREAMS_SCALING)
      DOUBLE PRECISION :: SCALING_QUAD_SINES  (MAXSTREAMS_SCALING)

!  Local parameter array

      DOUBLE PRECISION :: BRDF_PARS ( MAX_BRDF_PARAMETERS )

!  azimuth quadrature streams for BRDF

      DOUBLE PRECISION :: X_BRDF  ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: CX_BRDF ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: SX_BRDF ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: CXE_BRDF ( MAXSTHALF_BRDF )
      DOUBLE PRECISION :: SXE_BRDF ( MAXSTHALF_BRDF )

!  Local arrays for MSR quadrature

      DOUBLE PRECISION :: X_MUQUAD (max_msrs_muquad)
      DOUBLE PRECISION :: W_MUQUAD (max_msrs_muquad)
      DOUBLE PRECISION :: SX_MUQUAD (max_msrs_muquad)
      DOUBLE PRECISION :: WXX_MUQUAD (max_msrs_muquad)

      DOUBLE PRECISION :: X_PHIQUAD (max_msrs_phiquad)
      DOUBLE PRECISION :: W_PHIQUAD (max_msrs_phiquad)

!  Output BRDF functions
!  =====================

!  at quadrature (discrete ordinate) angles

      DOUBLE PRECISION :: BRDFUNC &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTREAMS, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: BRDFUNC_0 &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXBEAMS, MAXSTREAMS_BRDF )

!  at user-defined stream directions

      DOUBLE PRECISION :: USER_BRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTREAMS, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: USER_BRDFUNC_0 &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXBEAMS, MAXSTREAMS_BRDF )

!  Exact DB values

      DOUBLE PRECISION :: DBKERNEL_BRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAX_USER_RELAZMS, MAXBEAMS )

!  Values for Emissivity

      DOUBLE PRECISION :: EBRDFUNC &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTHALF_BRDF, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: USER_EBRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTHALF_BRDF, MAXSTREAMS_BRDF )

!  Output for WSA/BSA scaling options. New, Version 2.7

      DOUBLE PRECISION :: SCALING_BRDFUNC &
          ( MAXSTREAMS_SCALING, MAXSTREAMS_SCALING, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: SCALING_BRDFUNC_0 &
          ( MAXSTREAMS_SCALING, MAXSTREAMS_BRDF )

!  local variables
!  ---------------

      INTEGER ::            I, UI, J, K, KE, IB, ORDER, NSQ
      INTEGER, PARAMETER :: LUM = 1
      INTEGER, PARAMETER :: LUA = 1
      DOUBLE PRECISION   :: KERNEL(16)

!  Local

      ORDER = MSRCORR_ORDER

!  Exact DB calculation
!  --------------------

!    !@@ Observational Geometry choice 12/31/12
!    !@@ Logic changed to include Overall EXACT calculation flag. 12/31/12

      IF ( DO_EXACT.and.DO_SOLAR_SOURCES ) THEN
        IF ( DO_USER_OBSGEOMS ) THEN
          DO IB = 1, NBEAMS
            !if(ORDER.eq.2)write(*,*)'Doing SZA/VZA = ',IB,UI
            IF ( DO_MSRCORR .or. DO_MSRCORR_EXACTONLY ) THEN
              CALL BRDF_VFUNCTION_DB &
               ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,  &
                 n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB),                     &
                 USER_STREAMS(IB), USER_SINES(IB), PHIANG(IB), COSPHI(IB), SINPHI(IB),  &
                 X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,       &
                 DBKERNEL_BRDFUNC(1,LUM,LUA,IB) )
            ELSE
              CALL BRDF_VFUNCTION &
               ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS,   &
                 NSTOKESSQ, SZASURCOS(IB), SZASURSIN(IB),      &
                 USER_STREAMS(IB), USER_SINES(IB), PHIANG(IB), &
                 COSPHI(IB), SINPHI(IB),                       &
                 DBKERNEL_BRDFUNC(1,LUM,LUA,IB) )
            ENDIF
          ENDDO
        ELSE
          DO K = 1, N_USER_RELAZMS
             DO IB = 1, NBEAMS
                DO UI = 1, N_USER_STREAMS
                   !if(ORDER.eq.2)write(*,*)'Doing SZA/VZA = ',IB,UI
                   IF ( DO_MSRCORR .or. DO_MSRCORR_EXACTONLY ) THEN
                     CALL BRDF_VFUNCTION_DB &
                      ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,  &
                        n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB),                     &
                        USER_STREAMS(UI), USER_SINES(UI), PHIANG(K), COSPHI(K), SINPHI(K),     &
                        X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,       &
                        DBKERNEL_BRDFUNC(1,UI,K,IB) )
                   ELSE
                     CALL BRDF_VFUNCTION &
                      ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS,  &
                        NSTOKESSQ, SZASURCOS(IB), SZASURSIN(IB),     &
                        USER_STREAMS(UI), USER_SINES(UI), PHIANG(K), &
                        COSPHI(K), SINPHI(K),                        &
                        DBKERNEL_BRDFUNC(1,UI,K,IB) )
                   ENDIF
                ENDDO
             ENDDO
          ENDDO
        END IF
      ENDIF

!  SCALING OPTIONS (New Section, Version 2.7)
!  ------------------------------------------

!  White-sky albedo, scaling. Only requires the (1,1) component
!     Use Local "Scaling_streams", both incident and outgoing

      IF ( DO_WSA_SCALING ) THEN
         NSQ = 1
         DO I = 1, SCALING_NSTREAMS
            DO J = 1, SCALING_NSTREAMS
               DO K = 1, NSTREAMS_BRDF
                  IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                     CALL BRDF_VFUNCTION_DB &
                        ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS,      &
                          ORDER, NSQ, n_muquad, n_phiquad,                 &
                          SCALING_QUAD_STREAMS(J), SCALING_QUAD_SINES(J),  &
                          SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I),  &         
                          X_BRDF(K), CX_BRDF(K), SX_BRDF(K),               &
                          X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,      &
                          KERNEL )
                     SCALING_BRDFUNC(I,J,K) = KERNEL(1)
                  ELSE
                     CALL BRDF_VFUNCTION &
                        ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, NSQ, &
                          SCALING_QUAD_STREAMS(J), SCALING_QUAD_SINES(J),  &
                          SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I),  &         
                          X_BRDF(K), CX_BRDF(K), SX_BRDF(K),               &
                          KERNEL )
                     SCALING_BRDFUNC(I,J,K) = KERNEL(1)
                  ENDIF
               ENDDO
            ENDDO
         ENDDO
      ENDIF

!  Black-sky albedo, scaling. Only requires the (1,1) component
!     Use Local "Scaling_streams" for outgoing, solar beam for incoming (IB = 1)

      IF ( DO_BSA_SCALING .and. DO_SOLAR_SOURCES ) THEN
         IB = 1 ; NSQ = 1
         DO I = 1, SCALING_NSTREAMS
            DO K = 1, NSTREAMS_BRDF
               IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                  CALL BRDF_VFUNCTION_DB &
                      ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSQ,           &
                        n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB),                &
                        SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I),                   &
                        X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                                &
                        X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,  &
                        KERNEL )
                  SCALING_BRDFUNC_0(I,K) = KERNEL(1)
               ELSE
                  CALL BRDF_VFUNCTION &
                      ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS,     &
                        NSQ, SZASURCOS(IB), SZASURSIN(IB),              &
                        SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I), &
                        X_BRDF(K), CX_BRDF(K), SX_BRDF(K),              &
                        KERNEL )
                  SCALING_BRDFUNC_0(I,K) = KERNEL(1)
               ENDIF
            ENDDO
         ENDDO
      ENDIF

!  Return if the Exact BRDF is all that is required (scaled or not!)

      IF ( DO_EXACTONLY ) RETURN

!  Quadrature outgoing directions
!  ------------------------------

!  Incident Solar beam
!    !@@  Solar Optionality. 12/31/12

      IF ( DO_SOLAR_SOURCES ) THEN
        DO IB = 1, NBEAMS
          DO I = 1, NSTREAMS
            DO K = 1, NSTREAMS_BRDF
              IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                CALL BRDF_VFUNCTION_DB &
                ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,       &
                  n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), QUAD_STREAMS(I), &
                  QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                   &
                  X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,    &
                  BRDFUNC_0(1,I,IB,K) )
              ELSE
                CALL BRDF_VFUNCTION &
                ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, NSTOKESSQ, &
                  SZASURCOS(IB), SZASURSIN(IB), QUAD_STREAMS(I),         &
                  QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),      &
                  BRDFUNC_0(1,I,IB,K) )
              ENDIF
            ENDDO
          ENDDO
        ENDDO
      ENDIF

!  incident quadrature directions

      DO I = 1, NSTREAMS
        DO J = 1, NSTREAMS
          DO K = 1, NSTREAMS_BRDF
           IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
            CALL BRDF_VFUNCTION_DB &
               ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,         &
                 n_muquad, n_phiquad, QUAD_STREAMS(J), QUAD_SINES(J), QUAD_STREAMS(I), &
                 QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                     &
                 X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,      &
                 BRDFUNC(1,I,J,K) )
           ELSE
            CALL BRDF_VFUNCTION &
               ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, NSTOKESSQ, &
                 QUAD_STREAMS(J), QUAD_SINES(J), QUAD_STREAMS(I),       &
                 QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),      &
                 BRDFUNC(1,I,J,K) )
           ENDIF
          ENDDO
        ENDDO
      ENDDO

!  Emissivity (optional) - BRDF quadrature input directions

      IF ( DO_SURFACE_EMISSION ) THEN
        DO I = 1, NSTREAMS
          DO KE = 1, NBRDF_HALF
            DO K = 1, NSTREAMS_BRDF
             IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
              CALL BRDF_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,      &
                   n_muquad, n_phiquad, CXE_BRDF(KE), SXE_BRDF(KE),                   &
                   QUAD_STREAMS(I), QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K), &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,   &
                   EBRDFUNC(1,I,KE,K) )
             ELSE
              CALL BRDF_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, NSTOKESSQ,      &
                   CXE_BRDF(KE), SXE_BRDF(KE), QUAD_STREAMS(I), QUAD_SINES(I), &
                   X_BRDF(K),  CX_BRDF(K), SX_BRDF(K),                         &
                   EBRDFUNC(1,I,KE,K) )
             ENDIF
            ENDDO
          ENDDO
        ENDDO
      ENDIF

!  User-streams outgoing directions
!  --------------------------------

      IF ( DO_USER_STREAMS ) THEN

!  Incident Solar beam, Outgoing User-stream
!    !@@ Observational Geometry choice + Solar Optionality. 12/31/12

        IF (DO_SOLAR_SOURCES ) THEN
          IF ( DO_USER_OBSGEOMS ) THEN
            DO IB = 1, NBEAMS
              DO K = 1, NSTREAMS_BRDF
               IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                 CALL BRDF_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,        &
                   n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(IB), &
                   USER_SINES(IB), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                   &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                   USER_BRDFUNC_0(1,LUM,IB,K) )
               ELSE
                 CALL BRDF_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, NSTOKESSQ, &
                   SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(IB),        &
                   USER_SINES(IB), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),     &
                   USER_BRDFUNC_0(1,LUM,IB,K) )
               ENDIF
              ENDDO
            ENDDO
          ELSE
            DO IB = 1, NBEAMS
             DO UI = 1, N_USER_STREAMS
              DO K = 1, NSTREAMS_BRDF
               IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                CALL BRDF_VFUNCTION_DB &
                   ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,        &
                     n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(UI), &
                     USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                   &
                     X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                     USER_BRDFUNC_0(1,UI,IB,K) )
               ELSE
                CALL BRDF_VFUNCTION &
                   ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, NSTOKESSQ, &
                     SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(UI),        &
                     USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),     &
                     USER_BRDFUNC_0(1,UI,IB,K) )
               ENDIF
              ENDDO
             ENDDO
            ENDDO
          ENDIF
        ENDIF

!  incident quadrature directions, Outgoing User-stream

        DO UI = 1, N_USER_STREAMS
          DO J = 1, NSTREAMS
            DO K = 1, NSTREAMS_BRDF
             IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
              CALL BRDF_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,        &
                   n_muquad, n_phiquad, QUAD_STREAMS(J), QUAD_SINES(J),                 &
                   USER_STREAMS(UI), USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K), &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                   USER_BRDFUNC(1,UI,J,K) )
             ELSE
              CALL BRDF_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS,  &
                   NSTOKESSQ, QUAD_STREAMS(J), QUAD_SINES(J),   &
                   USER_STREAMS(UI), USER_SINES(UI), X_BRDF(K), &
                   CX_BRDF(K), SX_BRDF(K),                      &
                   USER_BRDFUNC(1,UI,J,K) )
             ENDIF
            ENDDO
          ENDDO
        ENDDO

!  Emissivity (optional) - BRDF quadrature input directions

        IF ( DO_SURFACE_EMISSION ) THEN
          DO UI = 1, N_USER_STREAMS
            DO KE = 1, NBRDF_HALF
              DO K = 1, NSTREAMS_BRDF
               IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                CALL BRDF_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS, ORDER, NSTOKESSQ,       &
                   n_muquad, n_phiquad, CXE_BRDF(KE), SXE_BRDF(KE),                     &
                   USER_STREAMS(UI), USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K), &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                   USER_EBRDFUNC(1,UI,KE,K) )
               ELSE
                CALL BRDF_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, BRDF_NPARS, BRDF_PARS,  &
                   NSTOKESSQ, CXE_BRDF(KE), SXE_BRDF(KE),       &
                   USER_STREAMS(UI), USER_SINES(UI), X_BRDF(K), &
                   CX_BRDF(K), SX_BRDF(K),                      &
                   USER_EBRDFUNC(1,UI,KE,K) )
               ENDIF
              ENDDO
            ENDDO
          ENDDO
        ENDIF

      ENDIF

!  Finish

      RETURN
      END SUBROUTINE VBRDF_MAKER

! 

      SUBROUTINE VBRDF_GCMCRI_MAKER &
         ( DO_WSA_SCALING, DO_BSA_SCALING,                                    & ! New line, Version 2.7
           DO_SOLAR_SOURCES, DO_USER_OBSGEOMS, DO_EXACT,                      &
           DO_EXACTONLY, DO_USER_STREAMS, DO_SURFACE_EMISSION,                &
           DO_SHADOW_EFFECT, DO_MSRCORR, DO_MSRCORR_EXACTONLY, MSRCORR_ORDER, &
           NSTREAMS_BRDF, NBRDF_HALF, NSTOKESSQ, NPARS,                       &
           NSTREAMS, NBEAMS, N_USER_STREAMS, N_USER_RELAZMS,                  &
           QUAD_STREAMS, QUAD_SINES, USER_STREAMS, USER_SINES,                &
           SZASURCOS, SZASURSIN, PHIANG, COSPHI, SINPHI, PARS,                &
           SCALING_NSTREAMS, SCALING_QUAD_STREAMS, SCALING_QUAD_SINES,        & ! New line, Version 2.7
           X_BRDF, CX_BRDF, SX_BRDF, CXE_BRDF, SXE_BRDF, n_muquad, n_phiquad, &
           X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,   &
           DBKERNEL_BRDFUNC, BRDFUNC, USER_BRDFUNC,                           & ! output
           BRDFUNC_0, USER_BRDFUNC_0, EBRDFUNC, USER_EBRDFUNC,                & ! Output
           SCALING_BRDFUNC, SCALING_BRDFUNC_0  )                                ! output, New line, Version 2.7

!  include file of dimensions and numbers

      USE VLIDORT_PARS
      USE vbrdf_sup_kernels_m

      IMPLICIT NONE

!  Prepares the bidirectional reflectance scatter matrices

!  Observational Geometry Inputs. Marked with !@@
!     Installed 31 december 2012.
!     Observation-Geometry input control.         (DO_USER_OBSGEOMS)
!     Added solar_sources flag for better control (DO_SOLAR_SOURCES)
!     Added Overall-exact flag for better control (DO_EXACT)

!  Input arguments
!  ===============

!  White-sky and Black-sky albedo scaling flags. New Version 2.7

      LOGICAL ::          DO_WSA_SCALING
      LOGICAL ::          DO_BSA_SCALING

!   !@@ Solar sources + Observational Geometry flag !@@

      LOGICAL ::          DO_SOLAR_SOURCES
      LOGICAL ::          DO_USER_OBSGEOMS

!  Exact only flag (no Fourier term calculations)

      LOGICAL ::          DO_EXACT
      LOGICAL ::          DO_EXACTONLY

!  Local flags

      LOGICAL ::          DO_USER_STREAMS
      LOGICAL ::          DO_SURFACE_EMISSION
      LOGICAL ::          DO_SHADOW_EFFECT

!  Multiple reflectance correction for Glitter kernels

      LOGICAL ::          DO_MSRCORR
      INTEGER ::          MSRCORR_ORDER
      LOGICAL ::          DO_MSRCORR_EXACTONLY

!  Number of Azimuth waudrature streams

      INTEGER ::          NSTREAMS_BRDF
      INTEGER ::          NBRDF_HALF

!  Local number of Stokes component matrix entries
!    value = 1 for most kernels, except GISS Cox-Munk

      INTEGER ::          NSTOKESSQ

!  Local number of Kernel parameters

      INTEGER ::          NPARS

!  Local angle control

      INTEGER ::          NSTREAMS
      INTEGER ::          NBEAMS
      INTEGER ::          N_USER_STREAMS
      INTEGER ::          N_USER_RELAZMS

!  Local angles

      DOUBLE PRECISION :: PHIANG(MAX_USER_RELAZMS)
      DOUBLE PRECISION :: COSPHI(MAX_USER_RELAZMS)
      DOUBLE PRECISION :: SINPHI(MAX_USER_RELAZMS)

      DOUBLE PRECISION :: SZASURCOS(MAXBEAMS)
      DOUBLE PRECISION :: SZASURSIN(MAXBEAMS)

      DOUBLE PRECISION :: QUAD_STREAMS(MAXSTREAMS)
      DOUBLE PRECISION :: QUAD_SINES  (MAXSTREAMS)

      DOUBLE PRECISION :: USER_STREAMS(MAX_USER_STREAMS)
      DOUBLE PRECISION :: USER_SINES  (MAX_USER_STREAMS)

!  Discrete ordinates (local, for Albedo scaling). New Version 2.7

      INTEGER          :: SCALING_NSTREAMS
      DOUBLE PRECISION :: SCALING_QUAD_STREAMS(MAXSTREAMS_SCALING)
      DOUBLE PRECISION :: SCALING_QUAD_SINES  (MAXSTREAMS_SCALING)

!  Local parameter array

      DOUBLE PRECISION :: PARS ( MAX_BRDF_PARAMETERS )

!  azimuth quadrature streams for BRDF

      DOUBLE PRECISION :: X_BRDF  ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: CX_BRDF ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: SX_BRDF ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: CXE_BRDF ( MAXSTHALF_BRDF )
      DOUBLE PRECISION :: SXE_BRDF ( MAXSTHALF_BRDF )

!  Local MSR quadrature control

      INTEGER          :: n_muquad, n_phiquad

!  Local arrays for MSR quadrature

      DOUBLE PRECISION :: X_MUQUAD (max_msrs_muquad)
      DOUBLE PRECISION :: W_MUQUAD (max_msrs_muquad)
      DOUBLE PRECISION :: SX_MUQUAD (max_msrs_muquad)
      DOUBLE PRECISION :: WXX_MUQUAD (max_msrs_muquad)

      DOUBLE PRECISION :: X_PHIQUAD (max_msrs_phiquad)
      DOUBLE PRECISION :: W_PHIQUAD (max_msrs_phiquad)

!  Output BRDF functions
!  =====================

!  at quadrature (discrete ordinate) angles

      DOUBLE PRECISION :: BRDFUNC &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTREAMS, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: BRDFUNC_0 &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXBEAMS, MAXSTREAMS_BRDF )

!  at user-defined stream directions

      DOUBLE PRECISION :: USER_BRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTREAMS, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: USER_BRDFUNC_0 &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXBEAMS, MAXSTREAMS_BRDF )

!  Exact DB values

      DOUBLE PRECISION :: DBKERNEL_BRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAX_USER_RELAZMS, MAXBEAMS )

!  Values for Emissivity

      DOUBLE PRECISION :: EBRDFUNC &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTHALF_BRDF, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: USER_EBRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTHALF_BRDF, MAXSTREAMS_BRDF )

!  Output for WSA/BSA scaling options. New, Version 2.7

      DOUBLE PRECISION :: SCALING_BRDFUNC &
          ( MAXSTREAMS_SCALING, MAXSTREAMS_SCALING, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: SCALING_BRDFUNC_0 &
          ( MAXSTREAMS_SCALING, MAXSTREAMS_BRDF )

!  local variables
!  ---------------

      INTEGER ::          I, UI, J, K, KE, IB, ORDER, NSQ
      LOGICAL ::          DOSHADOW
      INTEGER, PARAMETER :: LUM = 1
      INTEGER, PARAMETER :: LUA = 1
      DOUBLE PRECISION   :: KERNEL(16)

!  Local
!  -----

      DOSHADOW = DO_SHADOW_EFFECT
      ORDER = MSRCORR_ORDER

!  Exact DB calculation
!  --------------------

      IF ( DO_EXACT.and.DO_SOLAR_SOURCES ) THEN
        IF ( .NOT. DO_USER_OBSGEOMS ) THEN
          IF ( DO_MSRCORR .or. DO_MSRCORR_EXACTONLY ) THEN
            DO K = 1, N_USER_RELAZMS
              DO IB = 1, NBEAMS
                DO UI = 1, N_USER_STREAMS
                  CALL GCMCRI_VFUNCTION_DB &
                  ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,        &
                    n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(UI), &
                    USER_SINES(UI), PHIANG(K), COSPHI(K), SINPHI(K),                     &
                    X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                    DBKERNEL_BRDFUNC(1,UI,K,IB) )
                ENDDO
              ENDDO
            ENDDO
          ELSE
            DO K = 1, N_USER_RELAZMS
              DO IB = 1, NBEAMS
                DO UI = 1, N_USER_STREAMS
                  CALL GCMCRI_VFUNCTION &
                  ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                    SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(UI),        &
                    USER_SINES(UI), PHIANG(K), COSPHI(K), SINPHI(K),       &
                    DBKERNEL_BRDFUNC(1,UI,K,IB) )
                ENDDO
              ENDDO
            ENDDO
          ENDIF
        ELSE
          IF ( DO_MSRCORR .or. DO_MSRCORR_EXACTONLY ) THEN
            DO IB = 1, NBEAMS
              CALL GCMCRI_VFUNCTION_DB &
              ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,        &
                n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(IB), &
                USER_SINES(IB), PHIANG(IB), COSPHI(IB), SINPHI(IB),                     &
                X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                DBKERNEL_BRDFUNC(1,LUM,LUA,IB) )
            ENDDO
          ELSE
            DO IB = 1, NBEAMS
              CALL GCMCRI_VFUNCTION &
              ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(IB),        &
                USER_SINES(IB), PHIANG(IB), COSPHI(IB), SINPHI(IB),       &
                DBKERNEL_BRDFUNC(1,LUM,LUA,IB) )
            ENDDO
          ENDIF
        ENDIF
      ENDIF

!  SCALING OPTIONS (New Section, Version 2.7)
!  ------------------------------------------

!  White-sky albedo, scaling
!     Use Local "Scaling_streams", both incident and outgoing

      IF ( DO_WSA_SCALING ) THEN
         NSQ = 1
         DO I = 1, SCALING_NSTREAMS
            DO J = 1, SCALING_NSTREAMS
               DO K = 1, NSTREAMS_BRDF
                  IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                     CALL GCMCRI_VFUNCTION_DB &
                        ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER,         &
                          NSQ, DOSHADOW, n_muquad, n_phiquad,              &
                          SCALING_QUAD_STREAMS(J), SCALING_QUAD_SINES(J),  &
                          SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I),  &         
                          X_BRDF(K), CX_BRDF(K), SX_BRDF(K),               &
                          X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,      &
                          KERNEL )
                     SCALING_BRDFUNC(I,J,K)  = KERNEL(1)
                  ELSE
                     CALL GCMCRI_VFUNCTION &
                        ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                          SCALING_QUAD_STREAMS(J), SCALING_QUAD_SINES(J),        &
                          SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I),        &         
                          X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                     &
                          KERNEL )
                     SCALING_BRDFUNC(I,J,K)  = KERNEL(1)
                  ENDIF
               ENDDO
            ENDDO
         ENDDO
      ENDIF

!  Black-sky albedo, scaling
!     Use Local "Scaling_streams" for outgoing, solar beam for incoming (IB = 1)

      IF ( DO_BSA_SCALING .and. DO_SOLAR_SOURCES ) THEN
         IB = 1
         DO I = 1, SCALING_NSTREAMS
            DO K = 1, NSTREAMS_BRDF
               IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
                  CALL GCMCRI_VFUNCTION_DB &
                     ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,     &
                       n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB),                &
                       SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I),                   &
                       X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                                &
                       X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,  &
                        KERNEL )
                     SCALING_BRDFUNC_0(I,K)  = KERNEL(1)
               ELSE
                  CALL GCMCRI_VFUNCTION &
                      ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ,    &
                        DOSHADOW, SZASURCOS(IB), SZASURSIN(IB),         &
                        SCALING_QUAD_STREAMS(I), SCALING_QUAD_SINES(I), &
                        X_BRDF(K), CX_BRDF(K), SX_BRDF(K),              &
                        KERNEL )
                     SCALING_BRDFUNC_0(I,K)  = KERNEL(1)
               ENDIF
            ENDDO
         ENDDO
      ENDIF

!  Return if this is all you require

      IF ( DO_EXACTONLY ) RETURN

!  Quadrature outgoing directions
!  ------------------------------

!  Incident Solar beam
!    !@@  Solar Optionality. 12/31/12

      IF ( DO_SOLAR_SOURCES ) THEN
        IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
          DO IB = 1, NBEAMS
            DO I = 1, NSTREAMS
              DO K = 1, NSTREAMS_BRDF
                CALL GCMCRI_VFUNCTION_DB &
                ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,       &
                  n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), QUAD_STREAMS(I), &
                  QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                   &
                  X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,    &
                  BRDFUNC_0(1,I,IB,K) )
              ENDDO
            ENDDO
          ENDDO
        ELSE
          DO IB = 1, NBEAMS
            DO I = 1, NSTREAMS
              DO K = 1, NSTREAMS_BRDF
                CALL GCMCRI_VFUNCTION &
                ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                  SZASURCOS(IB), SZASURSIN(IB), QUAD_STREAMS(I),         &
                  QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),      &
                  BRDFUNC_0(1,I,IB,K) )
              ENDDO
            ENDDO
          ENDDO
        ENDIF
      ENDIF

!  incident quadrature directions

    IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
      DO I = 1, NSTREAMS
        DO J = 1, NSTREAMS
          DO K = 1, NSTREAMS_BRDF
            CALL GCMCRI_VFUNCTION_DB &
               ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,         &
                 n_muquad, n_phiquad, QUAD_STREAMS(J), QUAD_SINES(J), QUAD_STREAMS(I), &
                 QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                     &
                 X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,      &
                 BRDFUNC(1,I,J,K) )
          ENDDO
        ENDDO
      ENDDO
    ELSE
      DO I = 1, NSTREAMS
        DO J = 1, NSTREAMS
          DO K = 1, NSTREAMS_BRDF
            CALL GCMCRI_VFUNCTION &
               ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                 QUAD_STREAMS(J), QUAD_SINES(J), QUAD_STREAMS(I),       &
                 QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),      &
                 BRDFUNC(1,I,J,K) )
          ENDDO
        ENDDO
      ENDDO
    ENDIF

!  Emissivity (optional) - BRDF quadrature input directions

    IF ( DO_SURFACE_EMISSION ) THEN
      IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
        DO I = 1, NSTREAMS
          DO KE = 1, NBRDF_HALF
            DO K = 1, NSTREAMS_BRDF
              CALL GCMCRI_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,     &
                   n_muquad, n_phiquad, CXE_BRDF(KE), SXE_BRDF(KE), QUAD_STREAMS(I), &
                   QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                 &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,  &
                   EBRDFUNC(1,I,KE,K) )
            ENDDO
          ENDDO
        ENDDO
      ELSE
        DO I = 1, NSTREAMS
          DO KE = 1, NBRDF_HALF
            DO K = 1, NSTREAMS_BRDF
              CALL GCMCRI_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                   CXE_BRDF(KE), SXE_BRDF(KE), QUAD_STREAMS(I),           &
                   QUAD_SINES(I), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),      &
                   EBRDFUNC(1,I,KE,K) )
            ENDDO
          ENDDO
        ENDDO
      ENDIF
    ENDIF

!  User-streams outgoing directions
!  --------------------------------

      IF ( DO_USER_STREAMS ) THEN

!  Incident Solar beam, Outgoing User-stream
!    !@@ Observational Geometry choice + Solar Optionality. 12/31/12

        IF (DO_SOLAR_SOURCES ) THEN
          IF (.NOT. DO_USER_OBSGEOMS ) THEN
            IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
             DO IB = 1, NBEAMS
              DO UI = 1, N_USER_STREAMS
               DO K = 1, NSTREAMS_BRDF
                 CALL GCMCRI_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,        &
                   n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(UI), &
                   USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                   &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                   USER_BRDFUNC_0(1,UI,IB,K) )
               ENDDO
              ENDDO
             ENDDO
            ELSE
             DO IB = 1, NBEAMS
              DO UI = 1, N_USER_STREAMS
               DO K = 1, NSTREAMS_BRDF
                  CALL GCMCRI_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                   SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(UI),        &
                   USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),     &
                   USER_BRDFUNC_0(1,UI,IB,K) )
               ENDDO
              ENDDO
             ENDDO
            ENDIF
          ELSE
            IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
             DO IB = 1, NBEAMS
               DO K = 1, NSTREAMS_BRDF
                 CALL GCMCRI_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,        &
                   n_muquad, n_phiquad, SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(IB), &
                   USER_SINES(IB), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                   &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,     &
                   USER_BRDFUNC_0(1,LUM,IB,K) )
               ENDDO
             ENDDO
            ELSE
             DO IB = 1, NBEAMS
               DO K = 1, NSTREAMS_BRDF
                 CALL GCMCRI_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                   SZASURCOS(IB), SZASURSIN(IB), USER_STREAMS(IB),        &
                   USER_SINES(IB), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),     &
                   USER_BRDFUNC_0(1,LUM,IB,K) )
               ENDDO
             ENDDO
            ENDIF
          ENDIF
        ENDIF

!  incident quadrature directions

       IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
        DO UI = 1, N_USER_STREAMS
          DO J = 1, NSTREAMS
            DO K = 1, NSTREAMS_BRDF
              CALL GCMCRI_VFUNCTION_DB &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,          &
                   n_muquad, n_phiquad, QUAD_STREAMS(J), QUAD_SINES(J), USER_STREAMS(UI), &
                   USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                     &
                   X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,       &
                   USER_BRDFUNC(1,UI,J,K) )
            ENDDO
          ENDDO
        ENDDO
       ELSE
        DO UI = 1, N_USER_STREAMS
          DO J = 1, NSTREAMS
            DO K = 1, NSTREAMS_BRDF
              CALL GCMCRI_VFUNCTION &
                 ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                   QUAD_STREAMS(J), QUAD_SINES(J), USER_STREAMS(UI),      &
                   USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),     &
                   USER_BRDFUNC(1,UI,J,K) )
            ENDDO
          ENDDO
        ENDDO
       ENDIF

!  Emissivity (optional) - BRDF quadrature input directions

        IF ( DO_SURFACE_EMISSION ) THEN
         IF ( DO_MSRCORR .and..not.DO_MSRCORR_EXACTONLY ) THEN
          DO UI = 1, N_USER_STREAMS
            DO KE = 1, NBRDF_HALF
              DO K = 1, NSTREAMS_BRDF
                CALL GCMCRI_VFUNCTION_DB &
                   ( MAX_BRDF_PARAMETERS, NPARS, PARS, ORDER, NSTOKESSQ, DOSHADOW,      &
                     n_muquad, n_phiquad, CXE_BRDF(KE), SXE_BRDF(KE), USER_STREAMS(UI), &
                     USER_SINES(UI), X_BRDF(K), CX_BRDF(K), SX_BRDF(K),                 &
                     X_MUQUAD, W_MUQUAD, SX_MUQUAD, WXX_MUQUAD, X_PHIQUAD, W_PHIQUAD,   &
                     USER_EBRDFUNC(1,UI,KE,K) )
              ENDDO
            ENDDO
          ENDDO
         ELSE
          DO UI = 1, N_USER_STREAMS
            DO KE = 1, NBRDF_HALF
              DO K = 1, NSTREAMS_BRDF
                CALL GCMCRI_VFUNCTION &
                   ( MAX_BRDF_PARAMETERS, NPARS, PARS, NSTOKESSQ, DOSHADOW, &
                     CXE_BRDF(KE), SXE_BRDF(KE), USER_STREAMS(UI),          &
                     USER_SINES(UI), X_BRDF(K),  CX_BRDF(K), SX_BRDF(K),    &
                     USER_EBRDFUNC(1,UI,KE,K) )
              ENDDO
            ENDDO
          ENDDO
         ENDIF
        ENDIF

      ENDIF

!  Finish

      RETURN
      END SUBROUTINE VBRDF_GCMCRI_MAKER

!

      SUBROUTINE SCALING_FOURIER_ZERO &
            ( DO_LOCAL_WSA, DO_LOCAL_BSA, LAMBERTIAN_FLAG, &
              SCALING_NSTREAMS, NSTREAMS_BRDF,             &
              A_BRDF, SCALING_BRDFUNC, SCALING_BRDFUNC_0,  &
              SCALING_BRDF_F, SCALING_BRDF_F_0 )

!  include file of dimensions and numbers

      USE VLIDORT_PARS

      IMPLICIT NONE

!  Prepares Fourier component of the bidirectional reflectance functions

!  Observational Geometry Inputs. Marked with !@@
!     Installed 31 december 2012.
!     Observation-Geometry input control.         (DO_USER_OBSGEOMS)
!     Added solar_sources flag for better control (DO_SOLAR_SOURCES)

!  Input arguments
!  ===============

!  Local flags

      LOGICAL ::          DO_LOCAL_WSA, DO_LOCAL_BSA

!  Control

      LOGICAL ::          LAMBERTIAN_FLAG

!  Local numbers

      INTEGER ::          SCALING_NSTREAMS, NSTREAMS_BRDF

!  Azimuth weights

      DOUBLE PRECISION :: A_BRDF ( MAXSTREAMS_BRDF )

!  Input for WSA/BSA scaling options. New, Version 2.7

      DOUBLE PRECISION :: SCALING_BRDFUNC   ( MAXSTREAMS_SCALING, MAXSTREAMS_SCALING, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: SCALING_BRDFUNC_0 ( MAXSTREAMS_SCALING, MAXSTREAMS_BRDF )

!  Output: Local kernel Fourier components
!  =======================================

!  at quadrature (discrete ordinate) angles

      DOUBLE PRECISION :: SCALING_BRDF_F   ( MAXSTREAMS_SCALING, MAXSTREAMS_SCALING )
      DOUBLE PRECISION :: SCALING_BRDF_F_0 ( MAXSTREAMS_SCALING   )

!  local variables
!  ===============

      INTEGER ::          I, J, K
      DOUBLE PRECISION :: SUM

!  Zeroing

      SCALING_BRDF_F        = ZERO
      SCALING_BRDF_F_0      = ZERO

!  Quadrature outgoing directions
!  ------------------------------

!  BSA: Incident Solar beam

      IF ( DO_LOCAL_BSA ) THEN
         IF ( .NOT. LAMBERTIAN_FLAG ) THEN
            DO I = 1, SCALING_NSTREAMS
               SUM = ZERO
               DO K = 1, NSTREAMS_BRDF
                  SUM  = SUM + SCALING_BRDFUNC_0(I,K)*A_BRDF(K)
               ENDDO
               SCALING_BRDF_F_0(I) = SUM * HALF
            ENDDO
         ELSE
            SCALING_BRDF_F_0 = ONE
         ENDIF
      ENDIF

!  WSA: incident quadrature directions

      if ( DO_LOCAL_WSA ) THEN
         IF ( .NOT. LAMBERTIAN_FLAG ) THEN
            DO I = 1, SCALING_NSTREAMS
               DO J = 1, SCALING_NSTREAMS
                  SUM = ZERO
                  DO K = 1, NSTREAMS_BRDF
                     SUM  = SUM + SCALING_BRDFUNC(I,J,K)*A_BRDF(K)
                  ENDDO
                  SCALING_BRDF_F(I,J) = SUM * HALF
               ENDDO
            ENDDO
         ELSE 
            SCALING_BRDF_F = ONE
         ENDIF
      ENDIF

!  Finish

      RETURN
      END SUBROUTINE SCALING_FOURIER_ZERO

!  

      SUBROUTINE VBRDF_FOURIER &
         ( DO_SOLAR_SOURCES, DO_USER_OBSGEOMS, &
           DO_USER_STREAMS, DO_SURFACE_EMISSION, &
           LAMBERTIAN_FLAG, M, NSTOKES, NSTOKESSQ, &
           NBEAMS, NSTREAMS, N_USER_STREAMS, NSTREAMS_BRDF, NBRDF_HALF, &
           DELFAC, FACTOR, BRDF_COSAZMFAC, BRDF_SINAZMFAC, &
           A_BRDF, BAX_BRDF, BRDFUNC, USER_BRDFUNC, BRDFUNC_0, &
           USER_BRDFUNC_0, EBRDFUNC, USER_EBRDFUNC, &
           LOCAL_BRDF_F, LOCAL_BRDF_F_0, LOCAL_USER_BRDF_F, &
           LOCAL_USER_BRDF_F_0, LOCAL_EMISSIVITY, &
           LOCAL_USER_EMISSIVITY )

!  include file of dimensions and numbers

      USE VLIDORT_PARS

      IMPLICIT NONE

!  Prepares Fourier component of the bidirectional reflectance functions

!  Observational Geometry Inputs. Marked with !@@
!     Installed 31 december 2012.
!     Observation-Geometry input control.         (DO_USER_OBSGEOMS)
!     Added solar_sources flag for better control (DO_SOLAR_SOURCES)

!  Input arguments
!  ===============

!   !@@ Solar sources + Observational Geometry flag !@@

      LOGICAL ::          DO_SOLAR_SOURCES
      LOGICAL ::          DO_USER_OBSGEOMS

!  Control

      LOGICAL ::          LAMBERTIAN_FLAG
      LOGICAL ::          DO_USER_STREAMS
      LOGICAL ::          DO_SURFACE_EMISSION

!  Local numbers

      INTEGER ::          M, NSTOKES, NSTOKESSQ
      INTEGER ::          NSTREAMS
      INTEGER ::          NBEAMS
      INTEGER ::          N_USER_STREAMS
      INTEGER ::          NSTREAMS_BRDF, NBRDF_HALF

!  Surface factors

      DOUBLE PRECISION :: DELFAC, FACTOR

!  Azimuth cosines/sines and weights

      DOUBLE PRECISION :: BRDF_COSAZMFAC ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: BRDF_SINAZMFAC ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: A_BRDF         ( MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: BAX_BRDF       ( MAXSTHALF_BRDF  )

!  at quadrature (discrete ordinate) angles

      DOUBLE PRECISION :: BRDFUNC &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTREAMS, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: BRDFUNC_0 &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXBEAMS, MAXSTREAMS_BRDF )

!  at user-defined stream directions

      DOUBLE PRECISION :: USER_BRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTREAMS, MAXSTREAMS_BRDF )
      DOUBLE PRECISION :: USER_BRDFUNC_0 &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXBEAMS, MAXSTREAMS_BRDF )

!  Values for Emissivity

      DOUBLE PRECISION :: EBRDFUNC &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTHALF_BRDF, MAXSTREAMS_BRDF)
      DOUBLE PRECISION :: USER_EBRDFUNC &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTHALF_BRDF, MAXSTREAMS_BRDF)

!  Output: Local kernel Fourier components
!  =======================================

!  at quadrature (discrete ordinate) angles

      DOUBLE PRECISION :: LOCAL_BRDF_F &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXSTREAMS )
      DOUBLE PRECISION :: LOCAL_BRDF_F_0 &
          ( MAXSTOKES_SQ, MAXSTREAMS, MAXBEAMS   )

!  at user-defined stream directions

      DOUBLE PRECISION :: LOCAL_USER_BRDF_F &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXSTREAMS )
      DOUBLE PRECISION :: LOCAL_USER_BRDF_F_0 &
          ( MAXSTOKES_SQ, MAX_USER_STREAMS, MAXBEAMS   )

!  emissivities

      DOUBLE PRECISION :: LOCAL_EMISSIVITY ( MAXSTOKES, MAXSTREAMS )
      DOUBLE PRECISION :: LOCAL_USER_EMISSIVITY ( MAXSTOKES, MAX_USER_STREAMS )

!  local variables
!  ===============

      INTEGER ::          I, UI, J, K, KPHI, IB, Q, O1, O2
      DOUBLE PRECISION :: SUM, REFL, HELP, EMISS(16)
      INTEGER ::          COSSIN_MASK(16)

      INTEGER, PARAMETER :: LUM = 1        !@@

      COSSIN_MASK = (/ 1,1,2,0,1,1,2,0,2,2,1,0,0,0,0,1 /)

!  surface factor

      HELP = HALF * DELFAC

!  Zeroing

      LOCAL_BRDF_F        = ZERO
      LOCAL_BRDF_F_0      = ZERO
      LOCAL_USER_BRDF_F   = ZERO
      LOCAL_USER_BRDF_F_0 = ZERO

!  Quadrature outgoing directions
!  ------------------------------

!  Incident Solar beam (direct beam reflections)
!    !@@ Solar Optionality, added 12/31/12

      IF ( DO_SOLAR_SOURCES ) THEN
        IF ( .NOT. LAMBERTIAN_FLAG ) THEN
          DO IB = 1, NBEAMS
            DO I = 1, NSTREAMS
              DO Q = 1, NSTOKESSQ
                SUM = ZERO
                IF ( COSSIN_MASK(Q) .EQ. 1 ) THEN
                  DO K = 1, NSTREAMS_BRDF
                    SUM  = SUM + BRDFUNC_0(Q,I,IB,K)*BRDF_COSAZMFAC(K)
                  ENDDO
                ELSE IF ( COSSIN_MASK(Q) .EQ. 2 ) THEN
                  DO K = 1, NSTREAMS_BRDF
                    SUM  = SUM + BRDFUNC_0(Q,I,IB,K)*BRDF_SINAZMFAC(K)
                  ENDDO
                ENDIF
                LOCAL_BRDF_F_0(Q,I,IB) = SUM * HELP
              ENDDO
            ENDDO
          ENDDO
        ELSE IF ( M .EQ. 0 ) THEN
          DO IB = 1, NBEAMS
            DO I = 1, NSTREAMS
              DO Q = 1, NSTOKESSQ
                LOCAL_BRDF_F_0(Q,I,IB) = ONE
              ENDDO
            ENDDO
          ENDDO
        ENDIF
      ENDIF

!  incident quadrature directions (surface multiple reflections)

      IF ( .NOT. LAMBERTIAN_FLAG ) THEN
        DO I = 1, NSTREAMS
          DO J = 1, NSTREAMS
            DO Q = 1, NSTOKESSQ
              SUM = ZERO
              IF ( COSSIN_MASK(Q) .EQ. 1 ) THEN
                DO K = 1, NSTREAMS_BRDF
                  SUM  = SUM + BRDFUNC(Q,I,J,K)*BRDF_COSAZMFAC(K)
                ENDDO
              ELSE IF ( COSSIN_MASK(Q) .EQ. 2 ) THEN
                DO K = 1, NSTREAMS_BRDF
                  SUM  = SUM + BRDFUNC(Q,I,J,K)*BRDF_SINAZMFAC(K)
                ENDDO
              ENDIF
              LOCAL_BRDF_F(Q,I,J) = SUM * HELP
            ENDDO
          ENDDO
        ENDDO
      ELSE IF ( M .EQ. 0 ) THEN
        DO I = 1, NSTREAMS
          DO J = 1, NSTREAMS
            DO Q = 1, NSTOKESSQ
              LOCAL_BRDF_F(Q,I,J) = ONE
            ENDDO
          ENDDO
        ENDDO
      ENDIF

!  debug information

!      IF ( DO_DEBUG_WRITE ) THEN
!        WRITE(555,'(A)')'BRDF_1 Fourier 0 quad values'
!        IF ( FOURIER .EQ. 0 ) THEN
!          DO I = 1, NSTREAMS
!          WRITE(555,'(1PE12.5,3x,1P10E12.5)')
!     & BIREFLEC_0(1,I,1),(BIREFLEC(1,I,J),J=1,NSTREAMS)
!         ENDDO
!        ENDIF
!      ENDIF

!  albedo check, always calculate the spherical albedo.
!   (Plane albedo calculations are commented out)


!  User-streams outgoing directions
!  --------------------------------

      IF ( DO_USER_STREAMS ) THEN

!  Incident Solar beam (direct beam reflections)
!     !@@ Observational Geometry option. Installed 12/31/12
!     !@@ Solar Optionality, added 12/31/12

        IF ( DO_SOLAR_SOURCES ) THEN
          IF ( DO_USER_OBSGEOMS ) THEN
            IF ( .NOT. LAMBERTIAN_FLAG ) THEN
              DO IB = 1, NBEAMS
                DO Q = 1, NSTOKESSQ
                  SUM = ZERO
                  IF ( COSSIN_MASK(Q) .EQ. 1 ) THEN
                    DO K = 1, NSTREAMS_BRDF
                      SUM=SUM+USER_BRDFUNC_0(Q,LUM,IB,K)*BRDF_COSAZMFAC(K)
                    ENDDO
                  ELSE IF ( COSSIN_MASK(Q) .EQ. 2 ) THEN
                    DO K = 1, NSTREAMS_BRDF
                      SUM=SUM+USER_BRDFUNC_0(Q,LUM,IB,K)*BRDF_SINAZMFAC(K)
                    ENDDO
                  ENDIF
                  LOCAL_USER_BRDF_F_0(Q,LUM,IB) = SUM * HELP
                ENDDO
              ENDDO
            ELSE IF ( M .EQ. 0 ) THEN
              DO IB = 1, NBEAMS
                DO Q = 1, NSTOKESSQ
                  LOCAL_USER_BRDF_F_0(Q,LUM,IB) = ONE
                ENDDO
              ENDDO
            ENDIF
          ELSE
            IF ( .NOT. LAMBERTIAN_FLAG ) THEN
              DO IB = 1, NBEAMS
                DO UI = 1, N_USER_STREAMS
                  DO Q = 1, NSTOKESSQ
                    SUM = ZERO
                    IF ( COSSIN_MASK(Q) .EQ. 1 ) THEN
                      DO K = 1, NSTREAMS_BRDF
                        SUM=SUM+USER_BRDFUNC_0(Q,UI,IB,K)*BRDF_COSAZMFAC(K)
                      ENDDO
                    ELSE IF ( COSSIN_MASK(Q) .EQ. 2 ) THEN
                      DO K = 1, NSTREAMS_BRDF
                        SUM=SUM+USER_BRDFUNC_0(Q,UI,IB,K)*BRDF_SINAZMFAC(K)
                      ENDDO
                    ENDIF
                    LOCAL_USER_BRDF_F_0(Q,UI,IB) = SUM * HELP
                  ENDDO
                ENDDO
              ENDDO
            ELSE IF ( M .EQ. 0 ) THEN
              DO IB = 1, NBEAMS
                DO UI = 1, N_USER_STREAMS
                  DO Q = 1, NSTOKESSQ
                    LOCAL_USER_BRDF_F_0(Q,UI,IB) = ONE
                  ENDDO
                ENDDO
              ENDDO
            ENDIF
          ENDIF
        ENDIF

!  incident quadrature directions (surface multiple reflections)

        IF ( .NOT. LAMBERTIAN_FLAG ) THEN
          DO UI = 1, N_USER_STREAMS
            DO J = 1, NSTREAMS
              DO Q = 1, NSTOKESSQ
                SUM = ZERO
                IF ( COSSIN_MASK(Q) .EQ. 1 ) THEN
                  DO K = 1, NSTREAMS_BRDF
                    SUM = SUM+USER_BRDFUNC(Q,UI,J,K)*BRDF_COSAZMFAC(K)
                  ENDDO
                ELSE IF ( COSSIN_MASK(Q) .EQ. 2 ) THEN
                  DO K = 1, NSTREAMS_BRDF
                    SUM = SUM+USER_BRDFUNC(Q,UI,J,K)*BRDF_SINAZMFAC(K)
                  ENDDO
                ENDIF
                LOCAL_USER_BRDF_F(Q,UI,J) = SUM * HELP
              ENDDO
            ENDDO
          ENDDO
        ELSE IF ( M .EQ. 0 ) THEN
          DO UI = 1, N_USER_STREAMS
            DO J = 1, NSTREAMS
              DO Q = 1, NSTOKESSQ
                LOCAL_USER_BRDF_F(Q,UI,J) = ONE
              ENDDO
            ENDDO
          ENDDO
        ENDIF

      ENDIF

!  Emissivity
!  ----------

!  Azimuth independent contribution, from Kirchhoff's law

      IF ( DO_SURFACE_EMISSION .AND. M .EQ. 0 ) THEN

!  Lambertian case

        IF ( LAMBERTIAN_FLAG ) THEN
          DO I = 1, NSTREAMS
            LOCAL_EMISSIVITY(1,I) = FACTOR
          ENDDO
          IF ( DO_USER_STREAMS ) THEN
            DO UI = 1, N_USER_STREAMS
              LOCAL_USER_EMISSIVITY(1,UI) = FACTOR
            ENDDO
          ENDIF
        ENDIF

!  bidirectional reflectance

        IF ( .NOT. LAMBERTIAN_FLAG ) THEN

!  Inserted Polarization sum here.   Still to be checked.....!!!!!!!

!  Quadrature polar directions

!mick fix
          EMISS = ZERO

          DO I = 1, NSTREAMS
            DO Q = 1, NSTOKESSQ
              REFL = ZERO
              DO KPHI= 1, NSTREAMS_BRDF
                SUM = ZERO
                DO K = 1, NBRDF_HALF
                  SUM = SUM + EBRDFUNC(Q,I,K,KPHI) * BAX_BRDF(K)
                ENDDO
                REFL = REFL + A_BRDF(KPHI) * SUM
              ENDDO
              EMISS(Q) = REFL
            ENDDO
            DO O1 = 1, NSTOKES
              REFL = ZERO
              DO O2 = 1, NSTOKES
                Q = 4 * ( O1 - 1 ) + O2
                REFL = REFL + EMISS(Q)
              ENDDO
              LOCAL_EMISSIVITY(O1,I) = REFL * FACTOR
            ENDDO
          ENDDO

!   user-defined polar directions

          IF ( DO_USER_STREAMS ) THEN
            DO UI = 1, N_USER_STREAMS
              DO Q = 1, NSTOKESSQ
                REFL = ZERO
                DO KPHI= 1, NSTREAMS_BRDF
                  SUM = ZERO
                  DO K = 1, NBRDF_HALF
                    SUM = SUM + USER_EBRDFUNC(Q,UI,K,KPHI)*BAX_BRDF(K)
                  ENDDO
                  REFL = REFL + A_BRDF(KPHI) * SUM
                ENDDO
                EMISS(Q) = REFL
              ENDDO
              DO O1 = 1, NSTOKES
                REFL = ZERO
                DO O2 = 1, NSTOKES
                  Q = 4 * ( O1 - 1 ) + O2
                  REFL = REFL + EMISS(Q)
                ENDDO
                LOCAL_USER_EMISSIVITY(O1,UI) = REFL * FACTOR
              ENDDO
            ENDDO
          ENDIF

        ENDIF

!  end emissivity clause

      ENDIF

!  Finish

      RETURN
      END SUBROUTINE VBRDF_FOURIER

!  End module

      END MODULE vbrdf_sup_routines_m
