snit::macro propagate {option "to" components} {
    option $option -configuremethod Propagate$option

    set body "\n"

    foreach comp $components {
        append body "\$$comp configure $option \$value\n"
    }

    method Propagate$option {option value} $body
}
