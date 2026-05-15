# Guardias

El objetivo principal de esta aplicación es controlar las guardias del personal.

## Caracteristicas de la aplicación

- Todo es local
- Solamente aplicación de escritorio (priorizar versiones antiguas de windows)
- Las guardias se distribuyen automaticamente (no se almacenan en base de datos)
- Los cambios específicos si se almacenan en base de datos
- Se asume por defecto que el trabajador asisitó a su guardia (confirmar esta caracteristica)
- La aplicación es escencialmente un calendario
- A la izquierda, cubriendo todo lo posible ne la ventana, un calendario
  - En cada celda se lista el nombre del trabajador asignado a ese día
- A la derecha, un panel con dos tabs
  - Un tab de estadisticas
    - lista de trabajadores en función donde se muestre la cantidad de guardias y descansos asignados en el mes actual
      - al hacer click en un trabajador
        - se resaltan las celdas del calendario donde está incluido
        - se habilitan los botones de acción debajo del calendario relacionados con trabajador en función
    - lista de trabajadores de vacaciones donde se muestre cuando se terminan
      - al hacer click en un trabajador
        - se habilitan los botones de acción debajo del calendario relacionados con trabajador de vacaciones
  - Un tab donde se listen los trabajadores
    - lista de trabajadores activos
    - lista de trabajadores de baja
    - botón para agregar trabajador
    - botón para dar de baja un trabajador
    - botón para reactivar un trabajador dado de baja
    - botón para eliminar trabajador dado de baja
- Debajo del calendario
  - grupo de botones relacionados con trabajador en función
    - asignar vacaciones (rango de fechas)
  - grupo de botones relacionado con trabajador de vacaciones
    - reconfigurar vacaciones (rango de fechas)
  - grupo de botones relacionado con las celdas
    - definir inasistencia

## Cosas que el usuario puede hacer

- Administrar la lista de trabajadores
- Decidir cuantas horas de trabajo son por trabajador
- Decidir cuantos trabajadores son en cada jornada
- Deliminar las vacaciones de cada trabajador (ejemplo: del 1 al 15 de mayo el trabajador 1 no se le asigna trabajo)
- Intercambiar guardias entre trabajadores (relevo)
- Marcar si el trabajador asistió o no a la guardía
- Ver la cantidad de guardías mensuales de cada trabajador
- Ver la cantidad de descansos mensuales de cada trabajador
