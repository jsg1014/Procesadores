/*
*Practica 1(Flex): estadisticas de diagramas de clases TikZ-UML en un documento LaTeX.
*
*Uso: ./tikzuml [fichero.tex]
*/

%option noyywrap nounput noinput nodefault

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NOMBRE_MAXIMO 256

enum {SIG_NOMBRE_PAQUETES,SIG_NOMBRE_CLASE,SIG_ATRIBUTOS,SIG_METODOS}

enum {MIEMBRO_VACIO,MIEMBRO_PUBLICA,MIEMBRO_PRIVADA,MIEMBRO_PROTEGIDA,MIEMBRO_OTRA}

/*Variables globales*/

static int num_paquetes=0,nivel=0,nivel_max=0;
static int publicos=0,privados=0,protegidos=0;
static char paquete_largo[NOMBRE_MAXIMO]="";
static int log_paquete =0;
static char clase_max[NOMBRE_MAXIMO]=0;
static int atributo_max=-1;

/*estados de analisis*/
static char clase_actual[NOMBRE_MAXIMO];
static int atributo_max;
static int siguiente;
static int prof;
static int vis;
static int estado_previo;
/*clases a usar*/

static void copiar (char *dst,const char *src);
static int long_uft8(const char *s);
static void marcar(int v);
static void cerrar_miembro();
static void cerrar_clases();

%}


ESPACIOS [\t\r\e]
COMENTARIOS "%".*
ORDEN "\\"[A-Za-z@]+
ESCAPE "\\"(.|\n)
VERB "\\verb""*"?("|"[^|\n]*"|"|"+"[^+\n]*"+"|"!"[^!\n]*"")
INI_VERB "\\begin{verbatim}"
FIN_VERB "\\end{veratim}"
INI_TIKZ "\\begin{tikzpicture}"
END_TIKZ "\\end{tikzpicture}"
INI_PAQUETE "\\begin{umlpackage}"
END_PAQUETE "\\end{umlpackage}"
END_DOC "\\end{document}"
CLASE "\\umlclass"
NOMBRE [^ \t\r%{}\\]+

/*comun dentro y fuera del tikz*/

<INITIAL,TIKZ>{COMENTARIOS}		;
<IITIAL,TIKZ>{VERB}	;
<INITIAL,TIKZ>{INI_VERB}	{estado_previo=YY_START;BEGIN(VERBATIM);}
<INITIAL,TIKZ>{END_DOC}		{yyterminated();}

/* fuera del tikz*/

<INITIAL>{INI_TIKZ}	{BEGIN(INITIAL);}
<INITIAL>{ORDEN}|{ESCAPE}	;
<INITIAL>[^\\%]+	;

/* dentro del tikz*/

<TIKZ>{INI_TIKZ}	{BEGIN(INI_TIKZ);}
<TIKZ>{INI_PAQUETE}	{
			 num_paquete++<
			 if(++nivel>nivel) nivel_max=nivel;
			 siguiente = SIG_NOMBRE_PAQUETE;
			 BEGIN(PRE);
			}
<TIKZ>{END_PAQUETE}	{if(nivel>0) nivel--;}
<TIKZ>{CLASE}/[^A-Za-z@]	{
				 clase_actual[0]='\0';
				 atrib_clase=0;
				 siguiente = SIG_NOMBRE_CLASE;
				 BEGIN(PRE);
				}
<TIKZ>{ORDEN}|{ESCAPE}	;
<TIKZ>[^\\%]+	;
