# bbdd2-tp-final
Adaptador y conversor de tablas

## Procedimiento

La tarea se dividirá en tres pasos:

1. Recorrer cada tabla de la base de datos de origen y llamar a SP_TABLE_COMPARE para cada una.
2. En base a la tabla, analizar las dos posibilidades y llamar a los SP correspondientes. Si la base de datos de destino tiene una tabla con este nombre, ir a SP_TABLE_TRANSFORM. Que modificará la tabla de destino para que coincida con la de origen. Si la base de datos destino no tiene una tabla con ese nombre, ir a SP_TABLE_COPY para copiar desde el origen hacia el destino.
3. Se ejecutará el SP correspondiente (a definir) para analizar si se responden a las norma de codificación exigidas.
