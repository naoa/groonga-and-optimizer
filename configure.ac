AC_PREREQ(2.59)
AC_INIT([groonga], 0.0.0, [naoya@createfield.com])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([expression_rewriters/and_optimizer.rb])
AM_CONFIG_HEADER([config.h])

AM_INIT_AUTOMAKE(foreign)
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

GROONGA_REQUIRED_VERSION=6.0.0
PKG_CHECK_MODULES([GROONGA], [groonga >= ${GROONGA_REQUIRED_VERSION}])

_PKG_CONFIG(GROONGA_PLUGINS_DIR, [variable=pluginsdir],    [groonga])
_PKG_CONFIG(GROONGA,             [variable=groonga],       [groonga])

GROONGA_PLUGINS_DIR="${pkg_cv_GROONGA_PLUGINS_DIR}"
GROONGA="${pkg_cv_GROONGA}"

AC_SUBST(GROONGA_PLUGINS_DIR)
AC_SUBST(GROONGA)

expression_rewriter_pluginsdir="\${GROONGA_PLUGINS_DIR}/expression_rewriters"
AC_SUBST(expression_rewriter_pluginsdir)

AC_CONFIG_FILES([
  Makefile
  expression_rewriters/Makefile
  test/Makefile
])

AC_OUTPUT

echo "$PACKAGE_NAME $PACKAGE_VERSION configuration:"
echo "-----------------------"
echo "groonga index-selector"
echo "  install directory:     ${expression_rewriter_pluginsdir}"
