/*
 * Practica 1 (Flex): estadisticas de diagramas de clases TikZ-UML en un documento LaTeX.
 *
 * Uso: ./tikzuml [fichero.tex]
 */

%option noyywrap nounput noinput nodefault

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NOMBRE_MAXIMO 256

enum { SIG_NOMBRE_PAQUETE, SIG_NOMBRE_CLASE, SIG_ATRIBUTOS, SIG_METODOS };

enum { VIS_VACIO, VIS_PUBLICA, VIS_PRIVADA, VIS_PROTEGIDA, VIS_OTRA };

/* Variables globales */
static int num_paquetes = 0, nivel = 0, nivel_max = 0;
static int publicos = 0, privados = 0, protegidos = 0;
static char paquete_largo[NOMBRE_MAXIMO] = "";
static int long_paquete = 0;
static char clase_max[NOMBRE_MAXIMO] = "";
static int atributo_max = -1;

/* Estado del analisis */
static char clase_actual[NOMBRE_MAXIMO];
static int atributo_clase;
static int siguiente;
static int prof;
static int vis;
static int estado_previo;

static void copiar(char *dst, const char *src);
static int long_utf8(const char *s);
static void marcar(int v);
static void cerrar_miembro(void);
static void cerrar_clase(void);
%}

ESPACIOS    [ \t\r\n]
COMENTARIOS "%".*
ORDEN       "\\"[A-Za-z@]+
ESCAPE      "\\"(.|\n)
VERB        "\\verb""*"?("|"[^|\n]*"|"|"+"[^+\n]*"+"|"!"[^!\n]*"!")
INI_VERB    "\\begin{verbatim}"
FIN_VERB    "\\end{verbatim}"
INI_TIKZ    "\\begin{tikzpicture}"
FIN_TIKZ    "\\end{tikzpicture}"
INI_PAQUETE "\\begin{umlpackage}"
FIN_PAQUETE "\\end{umlpackage}"
FIN_DOC     "\\end{document}"
CLASE       "\\umlclass"
NOMBRE      [^ \t\r\n%{}\\]+

%x TIKZ VERBATIM PRE OPC NOMBRE MIEMBROS

%%

 /* Comun dentro y fuera del tikzpicture */
<INITIAL,TIKZ>{COMENTARIOS}     ;
<INITIAL,TIKZ>{VERB}            ;
<INITIAL,TIKZ>{INI_VERB}        { estado_previo = YY_START; BEGIN(VERBATIM); }
<INITIAL,TIKZ>{FIN_DOC}         { yyterminate(); }

 /* Fuera del tikzpicture */
<INITIAL>{INI_TIKZ}             { BEGIN(TIKZ); }
<INITIAL>{ORDEN}|{ESCAPE}|"\\"  ;
<INITIAL>[^\\%]+                ;

 /* Dentro del tikzpicture */
<TIKZ>{FIN_TIKZ}                { BEGIN(INITIAL); }
<TIKZ>{INI_PAQUETE}             {
                                  num_paquetes++;
                                  if (++nivel > nivel_max) nivel_max = nivel;
                                  siguiente = SIG_NOMBRE_PAQUETE;
                                  BEGIN(PRE);
                                }
<TIKZ>{FIN_PAQUETE}             { if (nivel > 0) nivel--; }
<TIKZ>{CLASE}/[^A-Za-z@]        {
                                  clase_actual[0] = '\0';
                                  atributo_clase = 0;
                                  siguiente = SIG_NOMBRE_CLASE;
                                  BEGIN(PRE);
                                }
<TIKZ>{ORDEN}|{ESCAPE}|"\\"     ;
<TIKZ>[^\\%]+                   ;

 /* Verbatim: solo termina con \end{verbatim} */
<VERBATIM>{FIN_VERB}            { BEGIN(estado_previo); }
<VERBATIM>[^\\]+|"\\"           ;

 /* Entre las partes de una definicion */
<PRE>{ESPACIOS}+                ;
<PRE>{COMENTARIOS}              ;
<PRE>"["                        { prof = 0; BEGIN(OPC); }
<PRE>"{"                        {
                                  if (siguiente == SIG_NOMBRE_PAQUETE ||
                                      siguiente == SIG_NOMBRE_CLASE)
                                      BEGIN(NOMBRE);
                                  else {
                                      prof = 0;
                                      vis = VIS_VACIO;
                                      BEGIN(MIEMBROS);
                                  }
                                }
<PRE>.                          { yyless(0); BEGIN(TIKZ); /* entrada inesperada */ }

 /* [opciones] */
<OPC>{COMENTARIOS}              ;
<OPC>{ESCAPE}|"\\"              ;
<OPC>"{"                        { prof++; }
<OPC>"}"                        { if (prof > 0) prof--; }
<OPC>"]"                        { if (prof == 0) BEGIN(PRE); }
<OPC>[^\\%{}\]]+                ;

 /* {nombre} */
<NOMBRE>{ESPACIOS}+             ;
<NOMBRE>{COMENTARIOS}           ;
<NOMBRE>{NOMBRE}                {
                                  if (siguiente == SIG_NOMBRE_PAQUETE) {
                                      int l = long_utf8(yytext);
                                      if (l > long_paquete) {
                                          long_paquete = l;
                                          copiar(paquete_largo, yytext);
                                      }
                                  } else {
                                      copiar(clase_actual, yytext);
                                  }
                                }
<NOMBRE>"}"                     {
                                  if (siguiente == SIG_NOMBRE_PAQUETE) {
                                      BEGIN(TIKZ);
                                  } else {
                                      siguiente = SIG_ATRIBUTOS;
                                      BEGIN(PRE);
                                  }
                                }
<NOMBRE>.                       ;

 /* {atributos} y {metodos} */
<MIEMBROS>{COMENTARIOS}         ;
<MIEMBROS>{ESPACIOS}+           ;
<MIEMBROS>"\\\\"                { if (prof == 0) cerrar_miembro(); else marcar(VIS_OTRA); }
<MIEMBROS>"\\#"                 { marcar(VIS_PROTEGIDA); }
<MIEMBROS>"+"                   { marcar(VIS_PUBLICA); }
<MIEMBROS>"-"                   { marcar(VIS_PRIVADA); }
<MIEMBROS>"{"                   { prof++; marcar(VIS_OTRA); }
<MIEMBROS>"}"                   {
                                  if (prof > 0) {
                                      prof--;
                                  } else {
                                      cerrar_miembro();
                                      if (siguiente == SIG_ATRIBUTOS) {
                                          siguiente = SIG_METODOS;
                                          BEGIN(PRE);
                                      } else {
                                          cerrar_clase();
                                          BEGIN(TIKZ);
                                      }
                                  }
                                }
<MIEMBROS>{ORDEN}|{ESCAPE}      { marcar(VIS_OTRA); /* \{ \} \% \_ \textbf ... */ }
<MIEMBROS>[^\\%{}+\- \t\r\n]+   { marcar(VIS_OTRA); }
<MIEMBROS>.                     { marcar(VIS_OTRA); }

%%

static void copiar(char *dst, const char *src)
{
    strncpy(dst, src, NOMBRE_MAXIMO - 1);
    dst[NOMBRE_MAXIMO - 1] = '\0';
}

static int long_utf8(const char *s)
{
    int n = 0;
    for (; *s; s++)
        if (((unsigned char)*s & 0xC0) != 0x80) n++;
    return n;
}

static void marcar(int v)
{
    if (vis == VIS_VACIO) vis = v;
}

static void cerrar_miembro(void)
{
    if (vis != VIS_VACIO) {
        if (siguiente == SIG_ATRIBUTOS) atributo_clase++;
        switch (vis) {
            case VIS_PUBLICA:   publicos++;   break;
            case VIS_PRIVADA:   privados++;   break;
            case VIS_PROTEGIDA: protegidos++; break;
        }
    }
    vis = VIS_VACIO;
}

static void cerrar_clase(void)
{
    if (atributo_clase > atributo_max) {
        atributo_max = atributo_clase;
        copiar(clase_max, clase_actual);
    }
}

int main(int argc, char *argv[])
{
    if (argc > 2) {
        fprintf(stderr, "Uso: %s [fichero]\n", argv[0]);
        return EXIT_FAILURE;
    }
    if (argc == 2 && (yyin = fopen(argv[1], "r")) == NULL) {
        perror(argv[1]);
        return EXIT_FAILURE;
    }

    yylex();

    printf("Paquetes: %d (anidamiento máximo: %d)\n", num_paquetes, nivel_max);
    printf("Miembros por visibilidad: públicos %d, privados %d, protegidos %d\n",
           publicos, privados, protegidos);
    if (atributo_max >= 0)
        printf("Clase con más atributos: %s (%d)\n", clase_max, atributo_max);
    else
        printf("Clase con más atributos: ninguna\n");
    if (num_paquetes > 0)
        printf("Nombre de paquete más largo: %s\n", paquete_largo);
    else
        printf("Nombre de paquete más largo: ninguno\n");

    if (yyin != stdin) fclose(yyin);
    return EXIT_SUCCESS;
}
