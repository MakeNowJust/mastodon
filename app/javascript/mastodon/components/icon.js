import React from 'react';
import PropTypes from 'prop-types';
import classNames from 'classnames';

export default class Icon extends React.PureComponent {

  static propTypes = {
    id: PropTypes.string.isRequired,
    className: PropTypes.string,
    fixedWidth: PropTypes.bool,
    fontGrandOrder: PropTypes.bool,
  };

  render () {
    const { id, className, fixedWidth, fontGrandOrder, ...other } = this.props;

    return (
      <i role='img' className={classNames(fontGrandOrder ? ['fgo',  `fgo-${id}`] : ['fa', `fa-${id}`, { 'fa-fw': fixedWidth }], className)} {...other} />
    );
  }

}
