/*
 * Practica 1 (Flex): estadisticas de diagramas de clases TikZ-UML en un documento LaTeX.
 *
 * Uso: ./tikzuml [fichero.tex]
 */
/*
*Opciones de flex:
* noyywrap para asi no tener que definir yywrap()
* nodefault: la uso para desactivar la regla que copiaria caracteres no reconocidos a stdout.
* nounput,noinput: para no generar las funciones auxiliares unput e input.
*/
%option noyywrap nounput noinput nodefault
/*Librerias que me permiten usar las funciones durante todo el prigrama */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/*Variable estatica que se usara durante el programa*/
#define NOMBRE_MAXIMO 256
/*Enumerado que almacena que argymento de una orden UML se espera procesar*/
enum { SIG_NOMBRE_PAQUETE, SIG_NOMBRE_CLASE, SIG_ATRIBUTOS, SIG_METODOS };
/*Enumeracion de las clasificaciones del primer simbolo de un miembro*/
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
 /*Funcines auxiliares las cuales estan realizadas en la parte de rutinas de usuario*/
static void copiar(char *dst, const char *src);
static int long_utf8(const char *s);
static void marcar(int v);
static void cerrar_miembro(void);
static void cerrar_clase(void);
%}
 /*Definiciones regulares con nombre para evitar repetir patrones */
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
/*Condiciones de arranque en modo exclusivo:
* TIKZ: Dentr de tikzpicture.
* VERBATIM: contenido que se ignora hasta \end{verbatim}.
* PRE: entre la orden UML y su siguiente argumento.
* OPC: dentro de un argumento opcional.
* NOMBRE: lectura del nombre contenido entre llaves
* MIEMBROS: lectura de atributos o metodos de una clase.
*/
%x TIKZ VERBATIM PRE OPC NOMBRE MIEMBROS

%%

 /* Comun dentro y fuera del tikzpicture, donde se ignora los comentarios fuera de initial y tikz, ademas de no interpretar lo que este dentro de verb. Cuando se inicia el verbatim se guarda el estado actual para regresar cuando acabe el verbatim */
<INITIAL,TIKZ>{COMENTARIOS}     ;
<INITIAL,TIKZ>{VERB}            ;
<INITIAL,TIKZ>{INI_VERB}        { estado_previo = YY_START; BEGIN(VERBATIM); }
<INITIAL,TIKZ>{FIN_DOC}         { yyterminate(); }

 /* Fuera del tikzpicture, donde solo nos importa el contenido dentro del tikzpicture, el resto nos da igual. */
<INITIAL>{INI_TIKZ}             { BEGIN(TIKZ); }
<INITIAL>{ORDEN}|{ESCAPE}|"\\"  ;
<INITIAL>[^\\%]+                ;

 /* Dentro del tikzpicture, si se encuentra el final, volvemos al estaod inicial
*
*Cuando se abre un paquete, incremento el numero de paquetes y si al incrementar el nivel es mayor que el guardado lo actualizamos y actualizamos el siguiente nombre y accedemos al PRE para admitir espacios y opciones. 
* Cuando se llega al fin de paquete se reduce el nivel hasta 0.
* Se reconoce \umlclass solo si despues no se encuentra una palabra
 */
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
 /* Se ignora otras ordenes o escapes dentro de la imagen, el resto que este incluido tambien se ignora.*/
<TIKZ>{ORDEN}|{ESCAPE}|"\\"     ;
<TIKZ>[^\\%]+                   ;

 /* Verbatim: solo termina con \end{verbatim} */
<VERBATIM>{FIN_VERB}            { BEGIN(estado_previo); }
<VERBATIM>[^\\]+|"\\"           ;

 /* Entre las partes de una definicion, los espacios y comentarios dentr ed PRE se permiten.
* Cuando se encuentre un [ se asigna la profundidad a 0 y empieza el analisis de comentarios.
* Cuando se encuentra {, el significado varia dependiendo del valor de la variable siguiente, en donde, si es nombre/clase se comienza el analisis de NOMBRE y si no es asi paso a MIEMBROS.
* Si no hay comienzo de argumento volvemos a TIKZ y devuelvo yyless(0)
*/
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

 /* [opciones], Se ignoran los comentarios y escapes */
<OPC>{COMENTARIOS}              ;
<OPC>{ESCAPE}|"\\"              ;
<OPC>"{"                        { prof++; }
<OPC>"}"                        { if (prof > 0) prof--; }
<OPC>"]"                        { if (prof == 0) BEGIN(PRE); }
<OPC>[^\\%{}\]]+                ;

 /* {nombre}, si el siguiente es igual SIG_NOMBRE del paquuete se hara una copia de yytext con caracteres utf_8, si l es mayor que longuitud del paquete se copiara con la funcion copiar para evitar que el nombre guardado exceda el tama;o m,aximo.
* Cuando se cierra  el nombre de paquete se vuelve a TIKZ si no se prepara el argumento obligatorio atributos.
* Uso el punto(.) para que cualquier otro caracter inesperado dentro del argumento del nombre no se tenga en cuenta.
*/
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

 /* {atributos} y {metodos},al saber que \ separa los miembros, promero comprubeo que la profundidad es diferente a 0, si no es asi, si se encuentra un # estamos en la protregida, + estamos en la publica y - en la privada
* Si se encuentra una { se abre un grupo anidado y hace que el miembro sea de visibilidad no especificada hasta no encontrar otro caracter.
* Cuando la profundidad es 0 se cierra el miembro, si es mayor a 0 se va decrementado la profundidad hasta 0. Si el siguiente es un atributo se asigna a metodos y comienza el PRE, si no se cierra la clase y comienza TIKZ.
*/
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

 /* Cualquier otro contenido no vacio tambien sera contenido de visibilidad y si no se encuentra un caracter +,- o \# su visivilidad quedara en otra.*/

<MIEMBROS>{ORDEN}|{ESCAPE}     { marcar(VIS_OTRA); /* \{ \} \% \_ \textbf ... */ }
<MIEMBROS>[^\\%{}+\- \t\r\n]+   { marcar(VIS_OTRA); }
<MIEMBROS>.                     { marcar(VIS_OTRA); }

%%
/*
* Copia segura ya que strncpy solo almacena un nombre que flex ya ha reconocido lexicamente, ademas tendra el tamano maximo de la variable estatica NOMBRE_MAXIMO
*/
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
 /*Registra la primera clasificacion de la visibilidad para el miembro encontrado*/
static void marcar(int v)
{
    if (vis == VIS_VACIO) vis = v;
}
 /*Cierra el miembro, si esta vacio no se tiene encuenta, si este no esta vacio y es atributo se aumentara la clase atributo_clase, solo se tendran en cuenta la visibilidad publica,privada y protegida ya que VIS_OTRAS representa una visibilidad no especificada.*/
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
/*
* Se usa al cerrar una clase y actualizara los atributos maximos si la nueva tiene estrictamente mas caracteres que la ya guardada y se realiza la copia. En caso de empate ganara la ya guardada previamente.
*/
static void cerrar_clase(void)
{
    if (atributo_clase > atributo_max) {
        atributo_max = atributo_clase;
        copiar(clase_max, clase_actual);
    }
}
/*Solo se permite la entrada del fichero, si existe el fichero se le asigna a yyin, si no es asi yyin se asignara a la entrada normal.
* Despues realizo la salida por pantalla de los datos especificados por la practica, realizando una comprobacion de que todos los datos a mostrar son mayor que 0.
* Si el fichero ha sido abierto correctamente, se cerrar con fclose(yyin) ya que yyin es el que contendra el contenido.
*/
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
