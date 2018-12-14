//
// MATLAB Compiler: 6.6 (R2018a)
// Date: Sun Nov 11 16:11:36 2018
// Arguments:
// "-B""macro_default""-W""cpplib:libMATPOWER""-T""link:lib""-v""-d""/people/han
// s464/helicsUseCaseScripts/modelDependency/transmission/wrapperHELICS""-I""/pe
// ople/hans464/helicsUseCaseScripts/modelDependency/transmission/wrapperHELICS"
// "-I""/people/hans464/repositories/matpower6.0""runpf.m""runopf.m""mpoption.m"
// "runpf_gov.m"
//

#ifndef __libMATPOWER_h
#define __libMATPOWER_h 1

#if defined(__cplusplus) && !defined(mclmcrrt_h) && defined(__linux__)
#  pragma implementation "mclmcrrt.h"
#endif
#include "mclmcrrt.h"
#include "mclcppclass.h"
#ifdef __cplusplus
extern "C" {
#endif

/* This symbol is defined in shared libraries. Define it here
 * (to nothing) in case this isn't a shared library. 
 */
#ifndef LIB_libMATPOWER_C_API 
#define LIB_libMATPOWER_C_API /* No special import/export declaration */
#endif

/* GENERAL LIBRARY FUNCTIONS -- START */

extern LIB_libMATPOWER_C_API 
bool MW_CALL_CONV libMATPOWERInitializeWithHandlers(
       mclOutputHandlerFcn error_handler, 
       mclOutputHandlerFcn print_handler);

extern LIB_libMATPOWER_C_API 
bool MW_CALL_CONV libMATPOWERInitialize(void);

extern LIB_libMATPOWER_C_API 
void MW_CALL_CONV libMATPOWERTerminate(void);

extern LIB_libMATPOWER_C_API 
void MW_CALL_CONV libMATPOWERPrintStackTrace(void);

/* GENERAL LIBRARY FUNCTIONS -- END */

/* C INTERFACE -- MLX WRAPPERS FOR USER-DEFINED MATLAB FUNCTIONS -- START */

extern LIB_libMATPOWER_C_API 
bool MW_CALL_CONV mlxRunpf(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);

extern LIB_libMATPOWER_C_API 
bool MW_CALL_CONV mlxRunopf(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);

extern LIB_libMATPOWER_C_API 
bool MW_CALL_CONV mlxMpoption(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);

extern LIB_libMATPOWER_C_API 
bool MW_CALL_CONV mlxRunpf_gov(int nlhs, mxArray *plhs[], int nrhs, mxArray *prhs[]);

/* C INTERFACE -- MLX WRAPPERS FOR USER-DEFINED MATLAB FUNCTIONS -- END */

#ifdef __cplusplus
}
#endif


/* C++ INTERFACE -- WRAPPERS FOR USER-DEFINED MATLAB FUNCTIONS -- START */

#ifdef __cplusplus

/* On Windows, use __declspec to control the exported API */
#if defined(_MSC_VER) || defined(__MINGW64__)

#ifdef EXPORTING_libMATPOWER
#define PUBLIC_libMATPOWER_CPP_API __declspec(dllexport)
#else
#define PUBLIC_libMATPOWER_CPP_API __declspec(dllimport)
#endif

#define LIB_libMATPOWER_CPP_API PUBLIC_libMATPOWER_CPP_API

#else

#if !defined(LIB_libMATPOWER_CPP_API)
#if defined(LIB_libMATPOWER_C_API)
#define LIB_libMATPOWER_CPP_API LIB_libMATPOWER_C_API
#else
#define LIB_libMATPOWER_CPP_API /* empty! */ 
#endif
#endif

#endif

extern LIB_libMATPOWER_CPP_API void MW_CALL_CONV runpf(int nargout, mwArray& MVAbase, mwArray& bus, mwArray& gen, mwArray& branch, mwArray& success, mwArray& et, const mwArray& casedata, const mwArray& mpopt, const mwArray& fname, const mwArray& solvedcase);

extern LIB_libMATPOWER_CPP_API void MW_CALL_CONV runopf(int nargout, mwArray& MVAbase, mwArray& bus, mwArray& gen, mwArray& gencost, mwArray& branch, mwArray& f, mwArray& success, mwArray& et, const mwArray& casedata, const mwArray& mpopt, const mwArray& fname, const mwArray& solvedcase);

extern LIB_libMATPOWER_CPP_API void MW_CALL_CONV mpoption(int nargout, mwArray& opt, const mwArray& varargin);

extern LIB_libMATPOWER_CPP_API void MW_CALL_CONV mpoption(int nargout, mwArray& opt);

extern LIB_libMATPOWER_CPP_API void MW_CALL_CONV runpf_gov(int nargout, mwArray& MVAbase, mwArray& bus, mwArray& gen, mwArray& branch, mwArray& success, mwArray& et, const mwArray& mpc, const mwArray& del_P, const mwArray& mpopt, const mwArray& fname, const mwArray& solvedcase);

/* C++ INTERFACE -- WRAPPERS FOR USER-DEFINED MATLAB FUNCTIONS -- END */
#endif

#endif
